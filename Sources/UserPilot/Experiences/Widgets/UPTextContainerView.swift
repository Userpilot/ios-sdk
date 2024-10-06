//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

/// A custom container view for displaying multiple text lines, each represented by a `UPTextView`.
internal class UPTextContainerView: UIStackView {

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
        axis = .vertical
        distribution = .fill
        alignment = .fill
        spacing = 8 // Adjust the spacing between the text views if needed
    }

    /// Configures the container with a list of lines, applying the specified styling
    /// and setting up each `UPTextView` with its corresponding line data.
    ///
    /// - Parameters:
    ///   - lines: A list of `Line` objects representing the text lines to display.
    ///   - style: The theme data containing styling attributes for the text views.
    ///   - experienceContentListener: A listener for handling content-related actions.
    func setupView(lines: [Line], style: ThemeData, experienceContentProtocol: ExperienceContentProtocol) {
        // Clear existing views before adding new ones
        arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Iterate through each line and create a corresponding UPTextView
        for line in lines {
            let textView = UPTextView()
            textView.setupView(line: line, style: style, experienceContentProtocol: experienceContentProtocol)
            addArrangedSubview(textView)
        }
    }
}
