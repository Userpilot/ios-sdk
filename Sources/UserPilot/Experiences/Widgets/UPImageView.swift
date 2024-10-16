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

internal class UPImageView: UIImageView {

    // MARK: - Initializers

    /// Initializes the image view with a specified frame.
    /// - Parameter frame: The frame rectangle for the image view, measured in points.
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    /// Initializes the image view from a storyboard or XIB.
    /// - Parameter coder: An unarchiver object.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    /// Common initializer for setting up view properties.
    private func initializeView() {
        translatesAutoresizingMaskIntoConstraints = false
        contentMode = .scaleAspectFit // Set content mode to scale aspect fit
        backgroundColor = .clear       // Set background color to clear
    }

    // MARK: - Setup Methods

    /**
     Configures the image view based on the provided `Line` data.
     
     - Parameter line: The `Line` object containing configuration and attributes for the image or icon to display.
     - Parameter imageLoader: An instance conforming to `ImageLoading` protocol to handle image loading.
     */
    func setupView(line: Line, imageLoader: ImageLoading) {
        setupAccessibility(line)

        guard let attrs = line.attrs else { return } // Ensure attributes are available

        // Determine the URL based on the line type
        let url = line.type == .image ? attrs.src : attrs.icon
        guard let url = url else { return }

        imageLoader.loadImage(target: self,
                              url: url,
                              placeholder: .lightGray,
                              blurHash: "",
                              size: CGSize(width: 200, height: 200))
    }

    private func setupAccessibility(_ line: Line) {
        isAccessibilityElement = true
        accessibilityLabel = "Submit Button"
        accessibilityHint = "Tap to submit the form"
        accessibilityTraits = .button
    }

}
