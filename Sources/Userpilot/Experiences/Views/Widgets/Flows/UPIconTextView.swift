//
//  UPIconTextView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom view that contains an icon (`UPImageView`) and a text label (`UPTextView`)
//  arranged horizontally within a `UIStackView`.
//

import Foundation
import UIKit

internal class UPIconTextView: UIStackView {

    // MARK: - Constants

    struct Constants {
        static let textLeftMargin: CGFloat = 8
    }
    // MARK: - Subviews

    /// Icon component of the view.
    private let imageView: UPImageView = {
        let imageView = UPImageView(frame: .zero)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: CGFloat(ThemeHandler.DefaultValues.iconImageDimensions)),
            imageView.heightAnchor.constraint(equalToConstant: CGFloat(ThemeHandler.DefaultValues.iconImageDimensions))
        ])
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    /// Text component of the view.
    private let textView: UPTextView = {
        let textView = UPTextView()
        return textView
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViewProperties()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupViewProperties()
    }

    /// Configures the view properties.
    private func setupViewProperties() {
        axis = .horizontal
        alignment = .center
        spacing = Constants.textLeftMargin
    }

    // MARK: - Configuration

    /**
     Sets up the views in this layout using the provided `Line` data, style, and interaction listener.
     
     - Parameters:
        - line: The data representing the content and styling for the icon and text.
        - theme: The `ExperienceTheme` instance that defines the style attributes for the text and icon.
        - experienceContentListener: The listener to handle interactions and events with this content.
     */
    func setupView(
        line: Line,
        theme: ExperienceTheme,
        imageLoader: ImageLoading,
        isRTL: Bool) {
        // Add the subviews to the stack view
        if isRTL && isAppRTL {
            addArrangedSubview(imageView)
            addArrangedSubview(textView)
        } else if !isRTL && !isAppRTL {
            addArrangedSubview(imageView)
            addArrangedSubview(textView)
        } else if isRTL && !isAppRTL {
            addArrangedSubview(textView)
            addArrangedSubview(imageView)
        } else {
            addArrangedSubview(textView)
            addArrangedSubview(imageView)
        }

        // Configure the imageView using the provided line data.
        imageView.setupView(line: line, imageLoader: imageLoader)

        // Configure the textView using the line data, style, and listener.
        textView.setupView(line: line, theme: theme)
    }
}
