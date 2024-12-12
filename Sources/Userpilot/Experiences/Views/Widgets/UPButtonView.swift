//
//  UPButtonView.swift
//  Userpilot SDK
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

    static let buttonHeight = CGFloat(50)

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

    override var intrinsicContentSize: CGSize {
        guard
            let titleLabel = self.titleLabel,
            let text = titleLabel.text,
            let font = titleLabel.font
        else {
            return CGSize(width: self.bounds.width, height: UPButtonView.buttonHeight)
        }
        let edgeInsets = CGFloat(16) // 8 top, 8 bottom ,8 left, 8 right
        let actualHight = text.height(
            withFont: font,
            width: self.bounds.width - edgeInsets) + edgeInsets
        return CGSize(width: self.bounds.width, height: max(actualHight, UPButtonView.buttonHeight))
    }

    // MARK: - Setup Methods

    /// Configures initial properties for the button.
    private func initializeView() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.masksToBounds = true
        titleLabel?.numberOfLines = 0
        titleLabel?.lineBreakMode = .byWordWrapping
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    /**
     Sets up the button view properties based on the provided configuration.

     This function configures the button text, text alignment, background, border, and other styles using the
     provided `Line` content and `ExperienceTheme` attributes. It also sets up a click listener to handle
     the specified action.

     - Parameters:
     - line: The `Line` configuration that provides content and style attributes for the button.
     - action: The button action to be performed on click.
     - theme: The `ExperienceTheme` that provides styling attributes such as colors and border properties.
     - callback: Optional callback function to handle button actions.
     */
    func setupViews(line: Line?,
                    action: ButtonAction?,
                    theme: ExperienceTheme,
                    callback: ((ButtonAction) -> Void)?) {
        self.action = action
        self.callback = callback

        setFont(with: line, and: theme)
        applyStyle(with: line, and: theme)
    }

    /// Applies font.
    func setFont(with line: Line?, and theme: ExperienceTheme) {
        let textStyleMark = line?.content?.first?.marks?.first(
            where: { $0.type == ThemeHandler.StyleName.textStyle })
        let fontSize = textStyleMark?.attrs?.fontSize?.toFontSize
        ?? CGFloat(ThemeHandler.DefaultValues.normalTextSize)

        var traits = [UIFontDescriptor.SymbolicTraits]()
        if let marks = line?.content?.first?.marks {
            if marks.first(where: { $0.type == ThemeHandler.StyleName.textBold }) != nil {
                traits.append(.traitBold)
            }
            if marks.first(where: { $0.type == ThemeHandler.StyleName.textItalic }) != nil {
                traits.append(.traitItalic)
            }
        }
        titleLabel?.font = UIFont.matching(fontName: theme.fontFamily,
                                           fontWeight: traits,
                                           fontSize: fontSize)
    }

    /// Applies text and styling.
    private func applyStyle(with line: Line?, and theme: ExperienceTheme) {
        guard let line else { return }
        setTitle(line.buttonTitle, for: .normal)
        contentHorizontalAlignment = line.buttonAlignment

        setTitleColor(theme.buttonTextColor, for: .normal)
        tintColor = theme.buttonBackgroundColor
        backgroundColor = theme.buttonBackgroundColor
        layer.cornerRadius = theme.buttonBorderRadius
        layer.borderWidth = theme.buttonBorderWidth
        layer.borderColor = theme.buttonBorderColor.cgColor
    }

    /// Handler for button tap action.
    @objc private func buttonTapped() {
        guard let action else { return }
        callback?(action)
    }
}
