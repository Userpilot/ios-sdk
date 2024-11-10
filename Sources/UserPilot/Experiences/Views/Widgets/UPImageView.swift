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

    /// A UIStackView that arranges its arranged subviews vertically with specified spacing.
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        return imageView
    }()

    // MARK: - Initializers

    /// Initializes the custom view with a specified frame.
    /// - Parameter frame: The frame rectangle for the view, measured in points.
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    /// Initializes the custom view from a storyboard or XIB.
    /// - Parameter coder: An unarchiver object.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    /// Common initializer for setting up view properties.
    private func initializeView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        addSubview(imageView)
    }

    // MARK: - Setup Methods

    /**
     Configures the image view based on the provided `Line` data.
     
     - Parameter line: The `Line` object containing configuration and attributes for the image or icon to display.
     - Parameter imageLoader: An instance conforming to `ImageLoading` protocol to handle image loading.
     */
    func setupView(line: Line, imageLoader: ImageLoading) {
        guard
            let attrs = line.attrs,
            let url = line.type == .image ? attrs.src : attrs.icon
        else { return }

        setupAccessibility(line)

        if line.type == .image {
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 300)
            ])
            imageView.contentMode = .scaleToFill
            imageView.layer.cornerRadius = 20
        } else {
            NSLayoutConstraint.activate([
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.widthAnchor.constraint(equalToConstant: UPIconTextView.Constants.iconWidth),
                imageView.heightAnchor.constraint(equalToConstant: UPIconTextView.Constants.iconHeight)
            ])
            imageView.contentMode = .scaleToFill
        }
        // Load the image into the UIImageView
        imageLoader.loadImage(target: imageView,
                              url: "https://i.imgur.com/5simaPh.jpeg",
                              placeholder: .lightGray,
                              blurHash: "UlH.7wozbckC_NoekCW=%zoJWBof%fofoes.",
                              size: CGSize(width: 300, height: 200))
    }

    private func setupAccessibility(_ line: Line) {
        guard let alt = line.attrs?.alt else { return }
        isAccessibilityElement = true
        accessibilityLabel = alt
        accessibilityHint = alt
        accessibilityTraits = .image
    }

}
