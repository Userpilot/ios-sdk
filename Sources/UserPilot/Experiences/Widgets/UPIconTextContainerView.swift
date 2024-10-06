//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

/// A container view that dynamically creates and manages multiple `UPIconTextView` components based on provided lines.
internal class UPIconTextContainerView: UIStackView {

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViewProperties()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupViewProperties()
    }

    /// Configures the properties of the stack view.
    private func setupViewProperties() {
        axis = .vertical
        alignment = .fill
        spacing = 4.0 // Default spacing between elements.
        distribution = .fillProportionally
    }

    // MARK: - Configuration

    /// Sets up the container view by dynamically creating and adding `UPIconTextView` components
    ///  based on the provided lines.
    ///
    /// - Parameters:
    ///   - lines: A list of `Line` objects representing the content to be displayed.
    ///   - style: The theme data used to style each `UPIconTextView` child in the container.
    ///   - experienceContentListener: An event listener to handle interactions with each `UPIconTextView`.
    func setupView(lines: [Line],
                   style: ThemeData,
                   experienceContentProtocol: ExperienceContentProtocol,
                   imageLoader: ImageLoading) {
        // Remove existing views before adding new ones.
        arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Iterate through each line and add corresponding `UPIconTextView` components to the container.
        for (index, line) in lines.enumerated() {
            // Create and set up a new `UPIconTextView` for the current line.
            let iconText = UPIconTextView()
            iconText.backgroundColor = UIColor.random()
            iconText.setupView(line: line,
                               style: style,
                               experienceContentProtocol: experienceContentProtocol,
                               imageLoader: imageLoader)
            addArrangedSubview(iconText)

            // Add a spacer view between `UPIconTextView` components if this is not the last line.
            if index < lines.count - 1 {
                let spacer = UPSpaceView()
                spacer.setHeight(10) // Set height for spacing between views.
                addArrangedSubview(spacer)
            }
        }
    }
}
