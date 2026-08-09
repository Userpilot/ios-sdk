//
//  UPImageView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom UIImageView subclass that configures itself based on a `Line` object.
//
//  Sizing mirrors the Android SDK's `UPImageView`, so an experience renders an image at the same size
//  and aspect on both platforms. The shape of it: `getImageSize` states what the backend *asked* for,
//  uncapped, and this view shrinks that to whatever width its container actually offers — the job
//  Android does in `onMeasure`. Neither platform enlarges an image to fill its container.
//

import Foundation
import UIKit

internal class UPImageView: UIView {

    // MARK: - Properties

    /// An `UIImageView` that displays the main image or icon.
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        return imageView
    }()

    /// The size this image *wants* to be, in points, from the backend's `style` and `actual_size` —
    /// the output of `getImageSize(for:)`.
    ///
    /// `nil` for every line type other than `.image`: an icon's box is fixed by its host
    /// (``UPIconTextView`` constrains this view directly), which is what makes ``fitToAvailableWidth()``
    /// leave it alone.
    private var desiredSize: CGSize?

    /// Height ÷ width of the source image, used to recompute the height when the desired size has to
    /// shrink to fit. The *source* ratio rather than the requested one, because that is the ratio the
    /// image is shrunk by — including when the backend asked for a box of a different shape.
    private var shrinkAspect: CGFloat = 1

    /// Held so repeated `setupView` calls resize the image instead of stacking another pair of
    /// constraints on it — this view is rebuilt per step, and the constraints used to be activated
    /// fresh on every call.
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?

    // MARK: - Initializers

    /// Initializes the custom view with a specified frame.
    /// - Parameter frame: The frame rectangle for the view, measured in points.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    /// Initializes the custom view from a storyboard or XIB.
    /// - Parameter coder: An unarchiver object.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup Methods

    /// Configures the view's subviews and properties.
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        addSubview(imageView)
    }

    /**
     Configures the `UPImageView` with the provided `Line` data.

     - Parameters:
        - line: The `Line` object containing attributes and configuration for the image or icon.
        - imageLoader: An object conforming to `ImageLoading` for handling image loading.
     */
    func setupView(
        line: Line,
        imageLoader: ImageLoading
    ) {
        guard let attributes = line.attrs else { return }

        setupAccessibility(for: line)

        // Determine the image source based on the line type.
        let imageUrl = (line.type == .image) ? attributes.src : attributes.icon

        // Only an image line is sized from the backend; an icon's box is fixed by its host.
        let imageSize: CGSize
        if line.type == .image {
            imageSize = getImageSize(for: line)
            desiredSize = imageSize
            shrinkAspect = sourceAspect(for: line, imageSize: imageSize)
        } else {
            imageSize = ThemeHandler.DefaultValues.iconImageSize
            desiredSize = nil
            shrinkAspect = 1
        }

        // Configure the layout and style.
        configureLayout(imageSize: imageSize)
        applyStyling(attributes)

        if let url = imageUrl {
            imageLoader.loadImage(target: imageView, url: url, blurHash: attributes.hash, size: imageSize)
        }
    }

    /// load image by URL
    func setupView(
        url: String,
        imageLoader: ImageLoading
    ) {
        imageView.contentMode = .scaleAspectFit
        imageLoader.loadImage(target: imageView, url: url, blurHash: nil, size: CGSize(width: 100, height: 100))
    }

    /// Shrinks the desired size to whatever width the container actually offers, preserving
    /// ``shrinkAspect``. The counterpart of Android's `onMeasure`.
    ///
    /// ## Why the limit is read here and not in `getImageSize(for:)`
    ///
    /// The limit used to be `screenWidth - contentMargin * 2`, computed while resolving the size, which
    /// assumed every host of this view was the carousel's full-bleed content area. It is not:
    /// `SlideOutContainerView` puts the same view inside a card that is itself inset from the screen
    /// edges, so the old figure over-estimated the room there and a wide image overflowed its card.
    ///
    /// The container states the real limit through this view's own width, so that is where it is read
    /// from. It also removes a timing problem — `setupView` runs before the view is added to its parent
    /// at every call site, so at the moment the size is resolved there is no parent to ask. Measuring
    /// instead of guessing is correct in any container, and re-derives itself for free on rotation.
    override func layoutSubviews() {
        super.layoutSubviews()
        fitToAvailableWidth()
    }

    private func fitToAvailableWidth() {
        guard
            let desired = desiredSize,
            let widthConstraint = imageWidthConstraint,
            let heightConstraint = imageHeightConstraint
        else { return }

        // A width of zero means the container has not measured this view yet. Treated as "no limit",
        // the same as Android's `UNSPECIFIED`: a parent measuring without a bound must not be told the
        // image is 0 wide.
        let available = bounds.width
        let fitted: CGSize
        if available <= 0 || desired.width <= available {
            fitted = desired
        } else {
            fitted = CGSize(width: available, height: available * shrinkAspect)
        }

        guard
            abs(widthConstraint.constant - fitted.width) > 0.5
                || abs(heightConstraint.constant - fitted.height) > 0.5
        else { return }

        widthConstraint.constant = fitted.width
        heightConstraint.constant = fitted.height
    }

    /// Sets up accessibility for the image view.
    /// - Parameter line: The `Line` object containing accessibility attributes.
    private func setupAccessibility(for line: Line) {
        guard let altText = line.attrs?.alt else { return }
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = altText
        imageView.accessibilityTraits = .image
    }

    /// Pins the image inside this view, centred horizontally and driving this view's height.
    ///
    /// The height comes from the image rather than from a constant supplied by the call site: a caller
    /// cannot know the fitted height, because it depends on the width this view is given. Both call
    /// sites used to constrain this view to `getImageSize(...).height`, which was the capped figure and
    /// therefore wrong in an inset card.
    private func configureLayout(imageSize: CGSize) {
        if let widthConstraint = imageWidthConstraint, let heightConstraint = imageHeightConstraint {
            widthConstraint.constant = imageSize.width
            heightConstraint.constant = imageSize.height
            setNeedsLayout()
            return
        }

        let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: imageSize.width)
        let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: imageSize.height)
        imageWidthConstraint = widthConstraint
        imageHeightConstraint = heightConstraint

        // The vertical edges are pinned twice over: required inequalities so the image never spills out
        // of this view, and breakable equalities so this view *hugs* the image and reports a height at
        // all. Breakable because a host may constrain this view to a fixed box — `UPIconTextView` does
        // exactly that for an icon — and that box has to win rather than conflict.
        let topHug = imageView.topAnchor.constraint(equalTo: topAnchor)
        let bottomHug = imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        topHug.priority = .defaultHigh
        bottomHug.priority = .defaultHigh

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            topHug,
            bottomHug,
            widthConstraint,
            heightConstraint
        ])
        setNeedsLayout()
    }

    /// Applies styling attributes to the image views.
    /// - Parameter attributes: The attributes specifying styling options.
    private func applyStyling(_ attributes: Attributes) {
        let cornerRadius = attributes.imageRadius
        imageView.layer.cornerRadius = cornerRadius
        imageView.contentMode = attributes.imageScale
    }
}
