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
    private var callback: ((ButtonAction?) -> Void)?

    /// Survey Theme
    private var surveyTheme: SurveyTheme?

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
        if self.bounds.width == 0 {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = text.size(withAttributes: attributes)
            return CGSize(width: size.width + 40, height: max(actualHight, 40))
        } else {
            return CGSize(width: self.bounds.width, height: max(actualHight, UPButtonView.buttonHeight))
        }
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
    func setupViews(
        line: Line?,
        action: ButtonAction?,
        theme: ExperienceTheme,
        callback: ((ButtonAction?
                   ) -> Void)?) {
        self.action = action
        self.callback = callback

        setFont(with: line, and: theme)
        applyStyle(with: line, and: theme)
    }

    /**
     Sets up the button view properties based on the provided configuration.
     - Parameters:
     - title: The button title.
     - theme: The `SurveyTheme` that provides styling attributes such as colors and border properties.
     - callback: Optional callback function to handle button actions.
     */
    func setupViews(
        title: String,
        theme: SurveyTheme,
        callback: ((ButtonAction?) -> Void)?
    ) {
        surveyTheme = theme
        self.callback = callback

        titleLabel?.font = UIFont.matching(fontName: theme.fontFamily,
                                           fontWeight: [.traitBold],
                                           fontSize: 16)
        setTitle(title, for: .normal)
        setTitleColor(theme.primaryColorAsString.invertColor().color, for: .normal)
        setTitleColor(theme.primaryColorAsString.invertColor().color, for: .disabled)
        tintColor = theme.primaryColor
        backgroundColor = theme.primaryColor
        layer.cornerRadius = 12
        layer.borderColor = theme.primaryColor.cgColor
    }

    func setupViews(
        title: String?,
        npsTheme: NPSTheme,
        isSecondaryButton: Bool,
        isDismissButton: Bool,
        callback: ((ButtonAction?) -> Void)?
    ) {
            // Apply theme-based styling properties to the button
            titleLabel?.font = UIFont.matching(
                fontName: npsTheme.fontFamily,
                fontWeight: !isDismissButton ? [.traitBold] : [],
                fontSize: isSecondaryButton ? ThemeHandler.DefaultValues.surveyHighLowTextSize : 16
            )

            if isSecondaryButton {
                setTitleColor(npsTheme.backgroundColorAsString.invertColor().color, for: .normal)
            } else {
                setTitleColor(npsTheme.primaryColorAsString.invertColor().color, for: .normal)
            }

            setTitle(title, for: .normal)
            contentHorizontalAlignment = .center

            tintColor = isSecondaryButton ? .clear : npsTheme.primaryColor
            backgroundColor = isSecondaryButton ? .clear : npsTheme.primaryColor

            layer.cornerRadius = 12
            layer.borderWidth = 1
            layer.borderColor = (isSecondaryButton && !isDismissButton) ?
            ThemeHandler.DefaultValues.grayColor.cgColor : UIColor.clear.cgColor

            self.callback = callback
    }

    /// Applies font.
    func setFont(
        with line: Line?,
        and theme: ExperienceTheme
    ) {
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
    private func applyStyle(
        with line: Line?,
        and theme: ExperienceTheme
    ) {
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

    /// update button enabled state
    func updateEnableState(isEnabled: Bool) {
        guard let surveyTheme else { return }
        self.isEnabled = isEnabled
        layer.borderColor = isEnabled ? surveyTheme.primaryColor.cgColor : surveyTheme.secondaryColor.cgColor
        tintColor = isEnabled ? surveyTheme.primaryColor : surveyTheme.secondaryColor
        backgroundColor = isEnabled ? surveyTheme.primaryColor : surveyTheme.secondaryColor
    }

    /// Handler for button tap action.
    @objc private func buttonTapped() {
        callback?(action)
    }
}
