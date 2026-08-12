//
//  UPButtonRole.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Where a button sits in the action hierarchy, and the theme colours that follow from that.
//  Replaces the pair of booleans (`isSecondaryButton`, `isDismissButton`) that used to decide
//  an NPS button's appearance at each call site.
//

import UIKit

/// A button's place in Apple's action hierarchy: one filled primary, a tinted secondary beside
/// it, and a plain tertiary for the escape hatch.
///
/// The two booleans this replaces could express four states, only three of which were real, and
/// neither of them said what the button *was* — a reader had to work back from
/// `isSecondaryButton: true, isDismissButton: true` to "this is the plain text button". Naming the
/// tier means the emphasis ladder is decided once, here, instead of being re-derived from colours
/// at every call site.
internal enum UPButtonRole {

    /// The step's single confirming action. Filled with the theme's primary colour.
    case primary

    /// An alternative action of equal standing but lower emphasis, sitting beside the primary.
    /// Filled with the same hue at low opacity — Apple's "medium emphasis".
    case secondary

    /// The way out: dismiss, close, ask me later. No fill and no border, so it reads as text.
    case tertiary
}

/// The resolved appearance for a role against a particular theme.
///
/// A plain value rather than a set of calls on the button, so the whole of a tier's look can be
/// read in one place and handed to ``UPButtonView`` as a unit.
internal struct UPButtonRoleStyle {
    let fill: UIColor
    let titleColor: UIColor
    let borderColor: UIColor
    let borderWidth: CGFloat
    let fontSize: CGFloat
    let fontTraits: [UIFontDescriptor.SymbolicTraits]

    /// Whether this tier may render as Liquid Glass when the resolver allows it.
    ///
    /// False for ``UPButtonRole/tertiary``: the material signals a surface, and a text button has
    /// none. ``UPButtonView/applyFill(color:cornerRadius:borderColor:borderWidth:)`` would reach
    /// the same conclusion from its transparent fill, but saying it here means the tier's
    /// behaviour is not an inference from one of its colours.
    let allowsGlass: Bool
}

internal extension UPButtonRole {

    // MARK: - Tuning

    /// Opacity of the secondary tier's tint over the card.
    ///
    /// Low enough to sit clearly below the primary, high enough to still read as a filled pill.
    private static let secondaryTintOpacity: CGFloat = 0.20

    /// Opacity of the neutral secondary fill — the fallback, and Apple's own alert-sheet secondary.
    private static let neutralTintOpacity: CGFloat = 0.10

    /// Set to `true` to give every secondary button the neutral grey fill instead of the theme's
    /// tint, matching Apple's alert sheet rather than the brand-tinted emphasis ladder.
    ///
    /// Kept as a switch because both readings are defensible and the choice is a design call, not
    /// a technical one. The tinted version stays on the brand; the neutral one is what the system
    /// ships. Either way the fallback below still applies.
    private static let usesNeutralSecondaryFill = false

    /// Smallest contrast ratio at which a fill is still distinguishable from the card behind it.
    ///
    /// Far below WCAG's 3:1 for component boundaries, and deliberately so — a subtle tint is the
    /// point of this tier, and 3:1 would reject every tint the design calls for. This only has to
    /// catch the degenerate case: a theme whose primary is already the colour of its own card, where
    /// the pill would otherwise be invisible now that the border is gone.
    private static let minimumFillContrast: CGFloat = 1.10

    /// Smallest contrast ratio at which the tertiary tier's title is readable on the card.
    ///
    /// WCAG's large-text minimum. A brand accent that clears this is left alone even if it would
    /// fail the 4.5:1 body-text bar, because overriding the customer's colour is the more
    /// destructive answer for the many themes that sit between the two thresholds.
    private static let minimumTitleContrast: CGFloat = 3.0

    private static let primaryFontSize: CGFloat = 16
    private static let subordinateFontSize: CGFloat = 14

    // MARK: - Resolution

    /// The appearance this role takes against `theme`.
    ///
    /// - Parameter theme: The NPS theme, whose `main.primary`, `main.background_color` and
    ///   `text.font_color` are the only colour inputs. Nothing here introduces a colour the
    ///   backend did not send.
    /// - Returns: The resolved fill, title colour, border and font for this tier.
    func style(for theme: NPSTheme) -> UPButtonRoleStyle {
        switch self {
        case .primary:
            return UPButtonRoleStyle(
                fill: theme.primaryColor,
                titleColor: theme.primaryColorAsString.invertColor().color,
                borderColor: .clear,
                borderWidth: 0,
                fontSize: Self.primaryFontSize,
                fontTraits: [.traitBold],
                allowsGlass: true
            )

        case .secondary:
            return UPButtonRoleStyle(
                // No border, unlike the outline button this replaces. Apple's secondary is a filled
                // shape; a stroke around a tint reads as a third thing that is neither.
                fill: Self.secondaryFill(for: theme),
                titleColor: theme.textColor,
                borderColor: .clear,
                borderWidth: 0,
                fontSize: Self.subordinateFontSize,
                fontTraits: [.traitBold],
                allowsGlass: true
            )

        case .tertiary:
            return UPButtonRoleStyle(
                fill: .clear,
                titleColor: Self.tertiaryTitleColor(for: theme),
                borderColor: .clear,
                borderWidth: 0,
                fontSize: Self.subordinateFontSize,
                fontTraits: [],
                allowsGlass: false
            )
        }
    }

    // MARK: - Colour Choices

    /// The secondary tier's fill: the theme's primary at low opacity, or the neutral fill when that
    /// tint cannot be told apart from the card.
    ///
    /// The check is what makes dropping the border safe. `#F5F5F5` on `#FFFFFF` is a real theme, and
    /// at 20% it composites to within a hair of white — the old grey stroke was the only thing
    /// drawing that button, so removing it without this would have made the button vanish.
    private static func secondaryFill(for theme: NPSTheme) -> UIColor {
        let neutral = theme.textColor.withOpacity(neutralTintOpacity)
        guard !usesNeutralSecondaryFill else { return neutral }

        let tint = theme.primaryColor.withOpacity(secondaryTintOpacity)
        let rendered = tint.flattened(over: theme.backgroundColor)
        let isVisible = rendered.upContrastRatio(against: theme.backgroundColor) >= minimumFillContrast

        return isVisible ? tint : neutral
    }

    /// The tertiary tier's title colour: the theme's primary, so the control reads as tappable,
    /// falling back to the body text colour when the primary is too close to the card to be read.
    ///
    /// `theme.textColor` is the safe fallback by construction — it is derived from the background's
    /// inverse whenever the theme does not set one explicitly.
    private static func tertiaryTitleColor(for theme: NPSTheme) -> UIColor {
        let accent = theme.primaryColor
        let isReadable = accent.upContrastRatio(against: theme.backgroundColor) >= minimumTitleContrast

        return isReadable ? accent : theme.textColor
    }
}
