//
//  UPButtonView.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom UIButton subclass that provides enhanced functionality and styling
//  capabilities based on provided configuration data.
//

import Foundation
import UIKit

internal class UPButtonView: UIButton {

    // MARK: - Properties

    /// The action to be triggered when the button is tapped.
    private var action: ButtonAction?

    /// The callback function to handle button actions.
    private var callback: ((ButtonAction) -> Void)?

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    // MARK: - Setup Methods

    /// Configures initial properties for the button.
    private func initializeView() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.masksToBounds = true
    }

    /**
     Sets up the button view properties based on the provided configuration.

     This function configures the button text, text alignment, background, border, and other styles using the
     provided `Line` content and `ThemeData` attributes. It also sets up a click listener to handle
     the specified action.

     - Parameters:
       - line: The `Line` configuration that provides content and style attributes for the button.
       - action: The button action to be performed on click.
       - style: The `ThemeData` that provides styling attributes such as colors and border properties.
       - callback: Optional callback function to handle button actions.
     */
    func setupViews(line: Line?, action: ButtonAction?, style: ThemeData, callback: ((ButtonAction) -> Void)?) {
        self.action = action
        self.callback = callback

        configureContent(with: line)
        applyStyle(using: style)
        configureContentAlignment(with: line?.attrs?.textAlign)

        // Set click listener to trigger the action's callback if provided
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    // MARK: - Configuration Helpers

    /// Configures the button's content based on the provided `Line`.
    ///
    /// - Parameter line: The `Line` containing content and style attributes for the button.
    private func configureContent(with line: Line?) {
        guard let firstContent = line?.content?.first else {
            setTitle("", for: .normal)
            return
        }

        UIView.performWithoutAnimation {
            for state in [UIControl.State.normal, .highlighted, .selected, .disabled] {
               self.setTitle(firstContent.text, for: state)
            }
            layoutIfNeeded()
        }
    }

    /// Applies styling attributes to the button based on the provided `ThemeData`.
    ///
    /// - Parameter style: The `ThemeData` object that contains button styling properties.
    private func applyStyle(using style: ThemeData) {
        backgroundColor = style.buttonBackgroundColor
        setTitleColor(style.buttonTextColor, for: .normal)
        layer.cornerRadius = style.buttonBorderRadius
        layer.borderWidth = style.buttonBorderWidth
        layer.borderColor = style.buttonBorderColor.cgColor

        let font = UIFont.matching(fontName: style.fontFamily,
                                   fontWeight: [],
                                   fontSize: CGFloat(ThemeHandler.DefaultValues.normalTextSize))
        titleLabel?.font = font
    }

    /// - Parameter alignment: The `TextAlignment` that defines the button's text alignment.
    private func configureContentAlignment(with alignment: TextAlignmentType?) {
        contentHorizontalAlignment = alignment?.buttonAlignment() ?? .center
        titleLabel?.textAlignment = alignment?.textAlignment() ?? .center
    }

    // MARK: - Action Handlers

    /// Handler for button tap action.
    @objc private func buttonTapped() {
        guard let action = action else { return }
        callback?(action)
    }
}
