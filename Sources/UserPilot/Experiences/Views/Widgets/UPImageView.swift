//
//  UPImageView.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  A custom UIImageView subclass that configures itself based on a `Line` object.
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
    func setupView(line: Line, imageLoader: ImageLoading) {
        guard let attributes = line.attrs else { return }

        self.setupAccessibility(for: line)

        // Determine the image source based on the line type.
        let imageUrl = (line.type == .image) ? attributes.src : attributes.icon
        let imageSize = (line.type == .image) ? getImageSize(for: line) : ThemeHandler.DefaultValues.iconImageSize

        // Configure the layout and style.
        self.configureLayout(for: line, imageSize: imageSize)
        self.applyStyling(attributes)

        if let url = imageUrl {
            imageLoader.loadImage(target: imageView, url: url, blurHash: attributes.hash, size: imageSize)
        }
    }

    /// Sets up accessibility for the image view.
    /// - Parameter line: The `Line` object containing accessibility attributes.
    private func setupAccessibility(for line: Line) {
        guard let altText = line.attrs?.alt else { return }
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = altText
        imageView.accessibilityTraits = .image
    }

    /// Configures the layout constraints for the image views based on the line type.
    /// - Parameter line: The `Line` object specifying the layout.
    private func configureLayout(for line: Line, imageSize: CGSize) {
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: imageSize.width),
            imageView.heightAnchor.constraint(equalToConstant: imageSize.height)
        ])
    }

    /// Applies styling attributes to the image views.
    /// - Parameter attributes: The attributes specifying styling options.
    private func applyStyling(_ attributes: Attributes) {
        let cornerRadius = attributes.imageRadius
        imageView.layer.cornerRadius = cornerRadius
        imageView.contentMode = attributes.imageScale
    }
}
