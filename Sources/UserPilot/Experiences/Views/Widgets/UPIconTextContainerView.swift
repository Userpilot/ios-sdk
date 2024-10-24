//
//  UPIconTextContainerView.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom container view that dynamically creates and manages multiple `UPIconTextView` components,
//  arranged vertically within a `UIStackView`.
//

import Foundation
import UIKit

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
        spacing = 4
        distribution = .fillProportionally
    }

    // MARK: - Configuration

    /**
     Sets up the container view by dynamically creating and adding `UPIconTextView` components
     based on the provided lines.
     
     - Parameters:
        - lines: A list of `Line` objects representing the content to be displayed.
        - theme: The `ExperienceTheme` used to style each `UPIconTextView` child in the container.
        - experienceContentListener: An event listener to handle interactions with each `UPIconTextView`.
     */
    func setupView(lines: [Line],
                   theme: ExperienceTheme,
                   imageLoader: ImageLoading) {
        // Remove existing views before adding new ones.
        arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Iterate through each line and add corresponding `UPIconTextView` components to the container.
        lines.forEach { line in
            // Create and set up a new `UPIconTextView` for the current line.
            let iconText = UPIconTextView()
            iconText.setupView(line: line,
                               theme: theme,
                               imageLoader: imageLoader)
            addArrangedSubview(iconText)

//            // Add a spacer view between `UPIconTextView` components if this is not the last line.
//            if index < lines.count - 1 {
//                let spacer = UPSpaceView()
//                spacer.setHeight(10)
//                addArrangedSubview(spacer)
//            }
        }
    }
}
