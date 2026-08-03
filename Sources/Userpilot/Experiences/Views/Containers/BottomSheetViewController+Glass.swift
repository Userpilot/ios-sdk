//
//  BottomSheetViewController+Glass.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Liquid Glass surface treatment for the bottom sheet, and the backdrop mask that makes it
//  work. Split out of `BottomSheetViewController.swift` to keep that file under the SwiftLint
//  file-length limit.
//

import UIKit

// MARK: - Surface styling

extension BottomSheetViewController {

    /// How far a glass sheet is inset from the display edges.
    ///
    /// 8 pt, which is what UIKit's own `.pageSheet` uses — measured off a real presented sheet at
    /// 8.0 / 8.7 / 8.3 pt on its left, right and bottom edges. Previously a guessed 10.
    static let glassEdgeInset: CGFloat = UPGlassMeasuredMetrics.sheetEdgeInset

    /// Paints the sheet's surface and its backdrop, in either the solid or the Liquid Glass
    /// treatment.
    ///
    /// Three appearances are possible, selected by configuration:
    /// 1. **Solid** — default, and every OS below 26. Opaque themed card over the full themed
    ///    backdrop. Identical to the appearance before Liquid Glass existed.
    /// 2. **Glass, unmasked** — `liquidGlassSheetsAndDialogs(true)` + `liquidGlassMaskedBackdrop(false)`.
    ///    Glass card over the full themed backdrop. The glass refracts the *backdrop* rather
    ///    than the host app, so it reads muddy grey. Selectable for comparison only.
    /// 3. **Glass, masked** — `liquidGlassSheetsAndDialogs(true)`, masking on by default. Glass card with
    ///    its own shape cut out of the backdrop, so the glass reaches the host app's pixels and
    ///    actually looks like glass.
    ///
    /// In every case the customer's `background_color` is honoured — as an opaque fill when
    /// solid, and as the glass tint when glass. The backdrop's configured colour and opacity are
    /// never altered; masking removes only the region the card already covers.
    func applySurfaceStyle(
        backgroundColor: UIColor,
        cornerRadius: CGFloat,
        backdropEnabled: Bool,
        backdropColor: UIColor,
        surfaceMaterial: SurfaceMaterial? = nil
    ) {
        themeCornerRadius = cornerRadius
        contentTopConstraint?.constant = UPCardMetrics.sheetContentTop
        // Remembered so the surface can be resolved again from the same inputs when something
        // outside the theme changes the answer — a second overlay appearing, or the interface style
        // or an accessibility setting changing while the sheet is on screen.
        lastSurfaceInputs = UPSurfaceInputs(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            backdropEnabled: backdropEnabled,
            backdropColor: backdropColor,
            surfaceMaterial: surfaceMaterial
        )

        // One question, one answer: whether this is glass, what fills it, how it dims and whether
        // the theme's radius applies are all decided together, in the resolver.
        let style = glassResolver?.surfaceStyle(
            surfaceMaterial: surfaceMaterial,
            themeBackground: backgroundColor,
            themeBackdrop: backdropColor,
            themeBackdropEnabled: backdropEnabled,
            appearance: traitCollection.userInterfaceStyle
        ) ?? UPSurfaceStyle(
            fill: .solid(backgroundColor),
            backdrop: backdropEnabled ? backdropColor : nil,
            masksBackdrop: false,
            usesConcentricCorners: false
        )

        surfaceStyle = style
        let usesGlass = style.fill.isGlass
        applyGlassInset(usesGlass)
        appliedCornerRadius = style.usesConcentricCorners ? glassCornerRadius() : cornerRadius

        // Flush to the screen bottom, only the top corners are visible. Inset, the sheet floats, so
        // all four corners round — and the two pairs get different radii, which is what UIKit's own
        // sheet does. The bottom pair follows the display's curvature (it sits against it); the top
        // pair uses Apple's flat 36 pt, since there is no geometry up there to be concentric with.
        //
        // Both are supplied as *fixed* values rather than by `UICornerRadius.containerConcentric`,
        // because the backdrop hole has to be cut from the same numbers as the card and a concentric
        // radius cannot be read back at any point. Cutting the hole from the nominal value while the
        // corner resolved to the display's curvature is what leaked undimmed content outside the
        // sheet's bottom corners. Measured during the iOS 26 spike (Q7–Q9).
        if usesGlass {
            appliedTopCornerRadius = UPGlassMeasuredMetrics.sheetTopCornerRadius
            mainContainerView.applyCorners(
                top: appliedTopCornerRadius,
                bottom: appliedCornerRadius
            )
            // The bottom radius: it is the corner an action button sits beside.
            mainContainerView.upCardCornerRadius = appliedCornerRadius
            installGlassBackground(style.fill)
        } else {
            appliedTopCornerRadius = appliedCornerRadius
            mainContainerView.applyCorners(.fixed(appliedCornerRadius), edges: .top)
            // Glass off, so nothing here overrides the theme's own button radius.
            mainContainerView.upCardCornerRadius = nil
            removeGlassBackground()
            UPGlassEffectView.install(style.fill, in: mainContainerView)
        }

        dimmedView.isHidden = style.backdrop == nil
        dimmedView.backgroundColor = style.backdrop

        masksBackdrop = style.masksBackdrop
        updateBackdropMask()
        publishCardEdge(usesGlass: usesGlass)
    }

    /// A solid sheet is flush with the screen, so its content measures from the safe area; a glass
    /// sheet floats above it, so it measures from the card's own edge. Exactly one is ever active.
    private func activateContentBottom(usesGlass: Bool) {
        contentBottomSafeAreaConstraint?.isActive = !usesGlass
        contentBottomCardConstraint?.isActive = usesGlass
    }

    /// Tells the content view where the card's border is, so the one element that belongs *on* the
    /// border — the step progress bar — can reach it.
    ///
    /// Only while the card is glass. A solid sheet is flush with the screen and keeps the radius the
    /// theme asked for, so the layout it already had is left exactly as it was.
    func publishCardEdge(usesGlass: Bool) {
        let aware = contentView.subviews.compactMap { $0 as? UPCardEdgeAware }
        guard !aware.isEmpty else { return }

        let edge = usesGlass
            ? UPCardEdge(
                contentTopInset: UPCardMetrics.sheetContentTop,
                contentHorizontalInset: UPCardMetrics.contentHorizontal)
            : nil
        aware.forEach { $0.applyCardEdge(edge) }
    }

    /// The radius for a glass sheet's bottom corners: concentric with the display.
    ///
    /// The theme's radius plays no part — while the surface is glass, iOS 26's geometry wins, the
    /// same rule the fill and the dim follow. The floor is Apple's own sheet *top* radius, which
    /// covers the two cases where there is nothing to be concentric with: a display with square
    /// corners, and the window between the theme being applied and the sheet reaching a window
    /// (there is nothing to measure against until then, and
    /// ``refreshGlassCornerRadiusIfNeeded()`` picks up the real value on the first layout pass).
    func glassCornerRadius() -> CGFloat {
        UPDisplayCornerRadius.concentricRadius(
            displayRadius: UPDisplayCornerRadius.measured(in: view),
            inset: BottomSheetViewController.glassEdgeInset,
            minimum: UPGlassMeasuredMetrics.sheetTopCornerRadius
        )
    }

    /// Re-rounds the sheet once the display can actually be measured.
    ///
    /// The theme is applied during `viewDidLoad`, before the sheet is in a window, so the first
    /// radius is the theme's. This runs from `viewDidLayoutSubviews`, where the measurement is
    /// available, and is a no-op from then on: the measured value is cached per device, and the
    /// comparison below stops the corners being re-applied on every subsequent layout pass.
    func refreshGlassCornerRadiusIfNeeded() {
        guard glassBackground != nil else { return }

        let target = glassCornerRadius()
        guard abs(target - appliedCornerRadius) > 0.5 else { return }

        appliedCornerRadius = target
        mainContainerView.applyCorners(top: appliedTopCornerRadius, bottom: target)
        mainContainerView.upCardCornerRadius = target
        // The material has to follow the correction too, or its edge keeps the 36 pt floor while
        // the card moves to the measured radius.
        shapeGlassBackground()
        publishCardEdge(usesGlass: true)
    }

    /// Insets the sheet from the display edges when it renders as glass, per Apple's half-sheet
    /// pattern:
    ///
    /// > Sheets feature an increased corner radius, and half sheets are inset from the edge of
    /// > the display to allow content to peek through from beneath them.
    ///
    /// This is what makes the rest of the treatment legible: flush to the edges there is no gap
    /// for host content to show through, so the material has nothing to refract at its edges, and
    /// the corners have no display curvature to be concentric with.
    ///
    /// Reverts to flush when glass is off, so the pre-iOS 26 layout is untouched.
    private func applyGlassInset(_ usesGlass: Bool) {
        let inset: CGFloat = usesGlass ? BottomSheetViewController.glassEdgeInset : 0
        leadingInsetConstraint?.constant = inset
        trailingInsetConstraint?.constant = -inset
        bottomInsetConstraint?.constant = -inset

        // Once the card floats, the safe area is no longer the right reference for the content's
        // bottom: everything between it and the card's edge would be dead space.
        contentBottomSafeAreaConstraint?.isActive = !usesGlass
        contentBottomCardConstraint?.isActive = usesGlass
    }

    /// Installs (or replaces) the glass background behind the sheet's content.
    private func installGlassBackground(_ fill: UPSurfaceFill) {
        removeGlassBackground()
        glassBackground = UPGlassEffectView.install(fill, in: mainContainerView)
        shapeGlassBackground()
    }

    /// Hands the material the same corner pair the card was just given, so the three shapes that
    /// have to agree — card, material, backdrop hole — are cut from one set of numbers.
    ///
    /// Called again from `refreshGlassCornerRadiusIfNeeded()`, because the bottom radius is only
    /// measurable once the sheet is in a window and the material must follow that correction.
    func shapeGlassBackground() {
        glassBackground?.applyMaterialCorners(
            top: appliedTopCornerRadius,
            bottom: appliedCornerRadius
        )
    }

    private func removeGlassBackground() {
        glassBackground?.removeFromSuperview()
        glassBackground = nil
    }

}

// MARK: - Backdrop mask

extension BottomSheetViewController {

    /// Cuts the sheet's shape out of the dimming backdrop so a glass surface refracts the host
    /// app instead of the scrim.
    ///
    /// Deliberately a mask rather than a change to the backdrop's colour or opacity. Those are
    /// configured by the customer in the Userpilot dashboard, and they stay exactly as
    /// configured everywhere the backdrop is still visible. Only the region the card already
    /// covers — which the user cannot see through anyway — is removed.
    ///
    /// Must run after layout, because it needs the sheet's resolved frame.
    func updateBackdropMask() {
        guard masksBackdrop, !suspendsBackdropMask, mainContainerView.bounds.height > 0 else {
            backdropMask.remove(from: dimmedView)
            return
        }

        // The hole matches the sheet's shape corner for corner, including the fact that its top and
        // bottom radii differ. A uniform hole leaves either a bright wedge of undimmed content
        // outside the sheet's corners, or a dark sliver inside them.
        backdropMask.apply(
            to: dimmedView,
            geometry: UPBackdropMaskGeometry(
                bounds: dimmedView.bounds,
                hole: dimmedView.convert(mainContainerView.bounds, from: mainContainerView),
                topRadius: appliedTopCornerRadius,
                bottomRadius: appliedCornerRadius
            )
        )
    }
}

// MARK: - Theme entry points

extension BottomSheetViewController {

    /// Customize the background color of the bottom sheet for `ExperienceTheme`. It has no card
    /// radius field, so the pre-iOS 26 default stands — read only when the surface resolves solid.
    func setBackgroundColor(_ theme: ExperienceTheme) {
        applySurfaceStyle(
            backgroundColor: theme.backgroundColor,
            cornerRadius: ThemeHandler.DefaultValues.slideOutCornerRadius,
            backdropEnabled: theme.backdropEnabled,
            backdropColor: theme.backdropBackground,
            surfaceMaterial: theme.surfaceMaterial
        )
    }

    /// Customize the background color of the bottom sheet for `SurveyTheme`
    func setBackgroundColor(_ theme: SurveyTheme) {
        applySurfaceStyle(
            backgroundColor: theme.backgroundColor,
            cornerRadius: theme.borderRadius,
            backdropEnabled: theme.backdropEnabled,
            backdropColor: theme.backdropBackground,
            surfaceMaterial: theme.surfaceMaterial
        )
    }

    /// Customize the background color of the bottom sheet for `NPSTheme`
    func setBackgroundColor(_ theme: NPSTheme) {
        applySurfaceStyle(
            backgroundColor: theme.backgroundColor,
            cornerRadius: theme.borderRadius,
            backdropEnabled: true,
            backdropColor: .black.withOpacity(0.4),
            surfaceMaterial: theme.surfaceMaterial
        )
    }
}

// Surface styling and the backdrop mask live in `BottomSheetViewController+Glass.swift`.

// MARK: - Show BottomSheet view controller

internal extension UIViewController {

    /// Present a `BottomSheetViewController` modally
    func presentBottomSheet(viewController: UIViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}
