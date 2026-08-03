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

    /// Horizontal breathing room either side of a wrapped title, so a pill is not tight on its text.
    /// Read from `UPButtonView+Shape.swift`, which owns the sizing.
    static let wrappedContentPadding = CGFloat(48)

    /// The action to be triggered when the button is tapped.
    private var action: ButtonAction?

    /// The callback function to handle button actions.
    private var callback: ((ButtonAction?) -> Void)?

    /// Survey Theme
    private var surveyTheme: SurveyTheme?

    /// Decides whether this button renders as Liquid Glass.
    ///
    /// Assigning it re-applies the current fill, so the owning view can set it before or after
    /// styling without caring about order.
    var glassResolver: GlassCapabilityResolving? {
        didSet { reapplyFill() }
    }

    /// The most recent fill requested by a `setupViews`/`applyStyle` call, replayed when the
    /// resolver arrives or changes.
    ///
    /// Not private: `UPButtonView+Shape.swift` reads it to restore the theme's radius when a button
    /// stops being inside a glass card.
    var pendingFill: Fill?

    /// A fill request, independent of how it ends up being rendered.
    struct Fill {
        let color: UIColor
        let cornerRadius: CGFloat
        let borderColor: UIColor
        let borderWidth: CGFloat
    }

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    /// Sizes the button to its title rather than stretching to fill.
    ///
    /// Off by default: the SDK's primary CTAs are pinned to both edges of their card and are meant to
    /// span it. The NPS follow-up step is the exception — two compact buttons side by side, which need
    /// to wrap their text and read as pills.
    ///
    /// This has to be an opt-in because ``intrinsicContentSize`` below reports the button's *current*
    /// width once it has one, which is right for a full-width CTA and prevents any hugging.
    var wrapsContentWidth: Bool = false {
        didSet {
            guard wrapsContentWidth != oldValue else { return }
            invalidateIntrinsicContentSize()
            reapplyFill()
        }
    }

    // MARK: - Setup Methods

    override func layoutSubviews() {
        super.layoutSubviews()
        // The shape depends on the button's height and on whether a card ancestor is publishing one;
        // neither is settled when the theme is applied. See `refreshCornerShapeIfNeeded`.
        refreshCornerShapeIfNeeded()
    }

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
        applyFill(color: theme.primaryColor, cornerRadius: 12, borderColor: theme.primaryColor)
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
            applyFill(
                color: isSecondaryButton ? .clear : npsTheme.primaryColor,
                cornerRadius: 12,
                borderColor: (isSecondaryButton && !isDismissButton)
                    ? ThemeHandler.DefaultValues.grayColor
                    : .clear,
                borderWidth: 1
            )

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
        applyFill(
            color: theme.buttonBackgroundColor,
            cornerRadius: theme.buttonBorderRadius,
            borderColor: theme.buttonBorderColor,
            borderWidth: theme.buttonBorderWidth
        )
    }

    /// update button enabled state
    func updateEnableState(isEnabled: Bool) {
        guard let surveyTheme else { return }
        self.isEnabled = isEnabled
        let fillColor = isEnabled ? surveyTheme.primaryColor : surveyTheme.secondaryColor
        tintColor = fillColor

        // The disabled title colour has to contrast with the *secondary* colour, since that is the
        // disabled fill. It was previously derived from the primary colour's inverse, so the text
        // was being matched against a background it never sits on — which is why "Submit" read as
        // near-white on near-white.
        setTitleColor(surveyTheme.secondaryColorAsString.invertColor().color, for: .disabled)

        applyFill(
            color: fillColor,
            cornerRadius: pendingFill?.cornerRadius ?? 12,
            borderColor: fillColor
        )
    }

    /// Applies a fill as either Liquid Glass or the layer-based styling used before iOS 26.
    ///
    /// Routing every fill through one place is what makes glass possible here at all. The glass
    /// treatment uses `UIButton.Configuration`, and a configuration takes over title rendering
    /// from `setTitle`/`setTitleColor`/`titleLabel.font` — so the title, colour and font have to
    /// be carried into it rather than left on the button. Doing that per-call-site (as an earlier
    /// attempt did) is how title styling gets silently lost.
    ///
    /// The theme's corner radius is applied through `background.cornerRadius`, **never**
    /// `cornerStyle`, which would discard the customer's configured value.
    ///
    /// Internal rather than private so tests can reach it: the themed entry points take `Line` and
    /// `ExperienceTheme`, which are `Decodable`-only and cannot be built in a test.
    func applyFill(
        color: UIColor,
        cornerRadius: CGFloat,
        borderColor: UIColor = .clear,
        borderWidth: CGFloat = 0
    ) {
        pendingFill = Fill(
            color: color,
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            borderWidth: borderWidth
        )

        // A button with a transparent fill is a text or outline button — its background is meant to
        // stay empty. `prominentGlass` with a clear `baseBackgroundColor` still draws the material, so
        // asking for glass here paints a light pill behind text that should have nothing behind it.
        // That is what put a white background on NPS's "Ask me later".
        let hasFill = color.cgColor.alpha > 0.01

        guard
            #available(iOS 15.0, *),
            isEnabled,
            hasFill,
            glassResolver?.allowsGlass(for: .chrome) == true,
            var glass = UIButton.Configuration.upGlass(.prominentGlass)
        else {
            // Disabled buttons deliberately never use glass. The material signals
            // interactivity — it is `isInteractive` and reacts to touch — so it is the wrong
            // treatment for a control that cannot be pressed. It also renders almost invisibly:
            // the disabled fill is the theme's light `secondaryColor`, and
            // `UIButton.Configuration` then applies its own disabled dimming on top of that,
            // leaving the button and its title barely distinguishable from the card.
            applyLegacyFill()
            return
        }

        glass.baseBackgroundColor = color
        glass.baseForegroundColor = currentTitleColor
        applyGlassCornerStyle(to: &glass, themeRadius: cornerRadius)
        // The theme's border is dropped, unlike its corner radius: a hard stroke is not how
        // this material separates itself from what is behind it. Glass draws its own edge — measured at
        // ~1 pt and roughly 40% lighter than the fill, in the fill's own hue. A themed stroke
        // over that either
        // fights the highlight or, where the theme's border colour differs from its background colour,
        // paints an unrelated outline around it.
        //
        // Outline buttons never reach here: a transparent fill takes the legacy path above, which is
        // what keeps their border — the only thing drawing them.
        glass.background.strokeColor = nil
        glass.background.strokeWidth = 0
        glass.contentInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)

        // Carry the title into the configuration, preserving the font and colour that the
        // caller already set via the legacy APIs.
        if let title = currentTitle {
            var attributed = AttributedString(title)
            attributed.font = titleLabel?.font ?? .systemFont(ofSize: 16, weight: .bold)
            attributed.foregroundColor = currentTitleColor
            glass.attributedTitle = attributed
        }

        // The configuration draws the background, so the layer must not draw a competing one.
        backgroundColor = .clear
        layer.borderWidth = 0
        configuration = glass
    }

    /// The pre-iOS 26 fill: a coloured layer with a border. Unchanged behaviour.
    private func applyLegacyFill() {
        guard let fill = pendingFill else { return }
        if #available(iOS 15.0, *) {
            // Clear any previously applied glass configuration so the layer styling below is
            // what actually draws.
            configuration = nil
        }
        backgroundColor = fill.color
        layer.cornerRadius = wrapsContentWidth ? wrappedCapsuleRadius : fill.cornerRadius
        layer.borderColor = fill.borderColor.cgColor
        layer.borderWidth = fill.borderWidth
    }

    /// Replays the last fill after the resolver changes.
    private func reapplyFill() {
        guard let fill = pendingFill else { return }
        applyFill(
            color: fill.color,
            cornerRadius: fill.cornerRadius,
            borderColor: fill.borderColor,
            borderWidth: fill.borderWidth
        )
    }

    /// Handler for button tap action.
    @objc private func buttonTapped() {
        callback?(action)
    }
}
