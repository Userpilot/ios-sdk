//
//  DatePickerDialog+Styling.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  How the date picker dialog is painted: its container, its dim, and the colours its contents pick.
//
//  Split from `DatePickerDialog.swift` to keep both files inside the 400-line limit, and because the
//  appearance is the part that has to know about themes and Liquid Glass while the rest of the widget
//  does not.
//

import UIKit

internal extension DatePickerDialog {

    /// Whether the dialog's own surface is dark enough to need light contents.
    var prefersLightContent: Bool {
        guard let themeBackground else { return false }
        return !themeBackground.isLightColor()
    }

    /// Styles the dialog container's background as a system alert's.
    ///
    /// This dialog used to paint itself as glass. Two problems came out of that, and both are the
    /// reason it no longer does:
    ///
    /// 1. It sits on **its own dim**, so the material refracted the scrim rather than the app, and
    ///    the two effects cancelled into a flat murky grey — the same cancellation the masked
    ///    backdrop exists to prevent for sheets and dialogs, which this widget has no equivalent of.
    /// 2. The container is rasterised (`shouldRasterize`), which flattens a live material anyway.
    ///
    /// What it uses instead is UIKit's own alert palette, resolved through the appearance pinned
    /// below — so the dialog matches a native `UIAlertController` in both light and dark rather than
    /// approximating one. `secondarySystemBackground` is the alert's fill: `#F2F2F2` in light,
    /// `#1C1C1E` in dark. Being a dynamic colour, it re-resolves itself whenever the pinned style
    /// changes, with no work here.
    ///
    /// Only the background changes: every frame and the button layout are untouched.
    func styleContainerBackground(_ container: UIView) {
        // Which of the two palettes to use. The survey's own darkness decides it, not the device's:
        // a dialog raised from a dark-themed survey belongs in the dark palette even on a light
        // device, which is the same rule the country picker menu follows.
        if let themeBackground {
            let appearance = UPGlassMeasuredMetrics.interfaceStyle(matching: themeBackground)
            container.overrideUserInterfaceStyle = appearance
            overrideUserInterfaceStyle = appearance
        }

        container.backgroundColor = .secondarySystemBackground
        container.applyCorners(.fixed(alertCornerRadius))

        // A hairline instead of the old 1 pt hard border: an alert separates itself from what is
        // behind it with the dim, not with an outline.
        container.layer.borderWidth = 0
        container.layer.shadowOpacity = 0
    }

    /// The alert's corner radius, measured from the system's own: 27 pt on iOS 26, 14 pt below it.
    ///
    /// The widget's legacy 7 pt predates both and reads noticeably square beside a real alert.
    var alertCornerRadius: CGFloat {
        guard glassResolver?.allowsGlass(for: .chrome) == true else { return 14 }
        return UPGlassMeasuredMetrics.alertCornerRadius
    }

    /// The dim behind the dialog: the value measured from a real system alert, resolved for the style
    /// the dialog is rendering in — 20% black in light, 48% in dark. UIKit dims more than twice as
    /// hard in dark mode, which is why one number cannot serve both.
    ///
    /// The same value bottom sheets and centre dialogs use, so every dimmed surface in the SDK dims
    /// alike.
    var backdropColor: UIColor {
        UPGlassMeasuredMetrics.backdropColor(for: traitCollection.userInterfaceStyle)
    }

    /// The hairline above and between the actions. `separator` is the system's own, and it is dynamic,
    /// so the pinned appearance resolves it to the right value in either palette.
    var separatorColor: UIColor { .separator }

    /// The size a system alert uses for its actions. The widget's own 14 pt read as a caption next to
    /// the 17 pt title above it.
    static var actionFontSize: CGFloat { 17 }

    /// The colour both actions share.
    ///
    /// A system alert tints its actions and distinguishes the preferred one by weight alone, so the
    /// brand's `primaryColor` is the closest analogue to that tint — and it is what the survey's own
    /// buttons already use.
    ///
    /// With one guard: a brand colour is chosen against the *card*, while these titles sit on the
    /// alert's own fill, so a dark brand can come out unreadable there. Below the 3:1 that WCAG asks
    /// of large text the title falls back to the system's `label`, which is correct in both palettes —
    /// a legible action matters more than a branded one.
    var actionTitleColor: UIColor {
        guard themeBackground != nil else { return buttonColor }
        guard Self.contrastRatio(buttonColor, contrastSurface) >= 3 else { return .label }
        return buttonColor
    }

    /// The alert's own fill, resolved for the palette in use — what the action titles actually sit on.
    private var contrastSurface: UIColor {
        UIColor.secondarySystemBackground.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: prefersLightContent ? .dark : .light)
        )
    }

    /// WCAG relative-luminance contrast ratio, 1...21.
    private static func contrastRatio(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let one = UPGlassMeasuredMetrics.relativeLuminance(of: first)
        let two = UPGlassMeasuredMetrics.relativeLuminance(of: second)
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    /// An alert-style action row. See ``UPAlertActionButton`` for why this is not `UPButtonView`.
    func makeButton() -> UPAlertActionButton {
        let button = UPAlertActionButton()
        button.prefersLightContent = prefersLightContent
        return button
    }

    /// `setupView()` runs from init, while callers inject the resolver immediately afterwards.
    /// Rebuild so the first presentation does not keep the legacy container created at init.
    func rebuildForResolverChange(from previous: GlassCapabilityResolving?) {
        guard glassResolver !== previous else { return }
        subviews.forEach { $0.removeFromSuperview() }
        setupView()
    }

}
