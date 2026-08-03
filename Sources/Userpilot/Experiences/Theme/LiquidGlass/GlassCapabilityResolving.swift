//
//  GlassCapabilityResolving.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The single decision point for "may this element render as Liquid Glass?".
//  Every glass-capable view asks this instead of writing its own `#available` ladder,
//  so the availability, host-configuration and theme rules live in exactly one place.
//

import UIKit

/// Which layer of the interface an element belongs to.
///
/// Apple's guidance treats Liquid Glass as a **functional layer** material for controls
/// and navigation that floats above the content layer, and warns against overusing it.
/// The SDK follows that split: `chrome` may use glass, the two surface kinds may only use
/// glass when explicitly opted in, and content-layer views never ask at all.
///
/// The surfaces are split by *how much of the screen they cover*, because that is what
/// decides the legibility risk — and therefore which host opt-in governs them.
internal enum GlassElementKind {

    /// Floating controls that sit above content: dismiss button, floating CTA container,
    /// popup menus, transient dialogs. Gated only by availability + the global switch.
    case chrome

    /// Backgrounds of the containers that float over a backdrop: the bottom sheet and the
    /// centre dialog. Additionally gated by an explicit opt-in, because these carry the
    /// customer's `background_color`. Governed by `Config.liquidGlassSheetsAndDialogs`.
    case sheetOrDialog

    /// Backgrounds of the experiences that take the whole screen: carousel step cards and
    /// the survey list. Highest legibility risk of the surfaces — they can hold dense,
    /// multi-section content and there is no backdrop to separate them from the host app —
    /// so they have their own opt-in and are never enabled by the sheet/dialog opt-in.
    /// Governed by `Config.liquidGlassFullScreen`.
    case fullScreen
}

/// Resolves whether Liquid Glass may be used, and with what tint.
///
/// Implementations must be side-effect free and cheap enough to call during view setup.
internal protocol GlassCapabilityResolving: AnyObject {

    /// Whether the running combination of SDK build, OS, host configuration and theme
    /// permits Liquid Glass for `kind`.
    ///
    /// - Parameters:
    ///   - kind: Which interface layer is asking.
    ///   - surfaceMaterial: The theme's resolved surface material, when the caller has a
    ///     theme in hand. Ignored for `.chrome`. Pass `nil` when the theme does not
    ///     specify one, in which case the host `Config` value (or the default) decides.
    /// - Returns: `true` when the caller should render glass, `false` to use its fallback.
    func allowsGlass(for kind: GlassElementKind, surfaceMaterial: SurfaceMaterial?) -> Bool

    /// The alpha applied to a theme background colour when it is used as a glass tint.
    ///
    /// - Parameter style: The interface style the element is currently rendering in.
    /// - Returns: A value in `0...1`.
    func glassTintAlpha(for style: UIUserInterfaceStyle) -> CGFloat

    /// Whether a glass card's own shape should be cut out of the dimming backdrop.
    ///
    /// Glass refracts whatever is behind it. With a dimming scrim in the way it refracts the
    /// scrim and renders muddy grey, so the two effects cancel out. Cutting the card's shape
    /// out of the backdrop lets the glass reach the host app's pixels **without altering the
    /// customer's configured backdrop colour or opacity**, which remain exactly as set
    /// everywhere the backdrop is still visible.
    var masksBackdropBehindGlassSurface: Bool { get }

    /// Whether a glass card dims with Apple's measured value rather than the theme's colour.
    var usesAppleDefaultBackdrop: Bool { get }

    /// Whether a glass card is filled with Apple's material rather than tinted with the theme's
    /// colour.
    var usesAppleDefaultBackground: Bool { get }

    /// Whether the SDK should drop or simplify its **own** animations because the user asked for
    /// reduced motion.
    ///
    /// Covers the transitions the SDK owns — dialog fade and slide, sheet travel, the Likert pulse.
    /// UIKit's own animations are its business. `false` whenever
    /// `Config.liquidGlassAccessibilityAdaptation(false)` opts out.
    var reducesSDKMotion: Bool { get }

    /// Whether an already-presented experience re-resolves its appearance when the interface style
    /// or an accessibility setting changes. From `Config.liquidGlassAccessibilityAdaptation(_:)`.
    var adaptsToAccessibilityChanges: Bool { get }
}

internal extension GlassCapabilityResolving {

    /// Convenience for callers with no theme material to offer (all chrome, and any
    /// surface asking before its theme is bound).
    func allowsGlass(for kind: GlassElementKind) -> Bool {
        allowsGlass(for: kind, surfaceMaterial: nil)
    }

    /// Defaults so a conformer only has to answer what it actually varies — production supplies
    /// these from `Userpilot.Config`.
    var usesAppleDefaultBackdrop: Bool { true }
    var usesAppleDefaultBackground: Bool { true }

    /// Defaults to "no adaptation", so a test double never has to think about accessibility and a
    /// conformer that ignores these behaves exactly as the SDK did before they existed.
    var reducesSDKMotion: Bool { false }
    var adaptsToAccessibilityChanges: Bool { false }

    /// The complete appearance for a bottom sheet or centre dialog surface.
    ///
    /// This is the one call a container makes, and it lives here — on the protocol rather than in
    /// any single implementation — so there is exactly one composition of these rules for every
    /// conformer, production and test alike. Everything the sheet and the dialog could otherwise
    /// decide separately is decided once, which is what stops the two drifting apart.
    ///
    /// Reads as a cascade, most decisive first:
    ///
    /// 1. **Not glass** → the theme is honoured exactly as it always was. Nothing below applies;
    ///    this is the pre-iOS 26 appearance, and every OS below 26 takes this path.
    /// 2. **Fill** → Apple's untinted material when ``usesAppleDefaultBackground`` is set, the
    ///    theme colour as a tint otherwise. Replacing the colour still keeps its light-or-dark
    ///    reading, by pinning the material's appearance to match.
    /// 3. **Backdrop** → Apple's measured dim when ``usesAppleDefaultBackdrop`` is set, the theme's
    ///    colour otherwise. A theme that disables the backdrop still gets none: the flag replaces
    ///    the colour, it does not force dimming on.
    /// 4. **Corners** → replaced whenever glass is in use, because iOS 26 rounds cards far more
    ///    than the pre-26 default and a 12 pt card inset from a 62 pt display corner does not read
    ///    as belonging to the system.
    ///
    /// - Parameters:
    ///   - kind: Which element is asking. A full-screen experience has its own opt-in, so it cannot
    ///     be resolved as a sheet or dialog surface would be.
    ///   - surfaceMaterial: The theme's `material`, when the caller has a theme in hand. `nil` when
    ///     the theme is silent, which lets the host configuration decide. Ignored for `.fullScreen`
    ///     and `.chrome`.
    ///   - themeBackground: The theme's `background_color` for the card.
    ///   - themeBackdrop: The theme's configured backdrop colour.
    ///   - themeBackdropEnabled: The theme's `backdrop_enabled`.
    ///   - appearance: The interface style the container is currently rendering in.
    func surfaceStyle(
        for kind: GlassElementKind = .sheetOrDialog,
        surfaceMaterial: SurfaceMaterial? = nil,
        themeBackground: UIColor,
        themeBackdrop: UIColor,
        themeBackdropEnabled: Bool,
        appearance: UIUserInterfaceStyle
    ) -> UPSurfaceStyle {
        guard allowsGlass(for: kind, surfaceMaterial: surfaceMaterial) else {
            return UPSurfaceStyle(
                fill: .solid(themeBackground),
                backdrop: themeBackdropEnabled ? themeBackdrop : nil,
                masksBackdrop: false,
                usesConcentricCorners: false
            )
        }

        let fill: UPSurfaceFill = usesAppleDefaultBackground
            ? .appleGlass(UPGlassMeasuredMetrics.interfaceStyle(matching: themeBackground))
            : .tintedGlass(themeBackground, alpha: glassTintAlpha(for: appearance))

        let backdrop: UIColor?
        if !themeBackdropEnabled {
            backdrop = nil
        } else if usesAppleDefaultBackdrop {
            // Apple dims relative to the *rendered* appearance, not the card's: the dim belongs to
            // the host app's context, which is what `appearance` describes.
            backdrop = UPGlassMeasuredMetrics.backdropColor(for: appearance)
        } else {
            backdrop = themeBackdrop
        }

        return UPSurfaceStyle(
            fill: fill,
            backdrop: backdrop,
            masksBackdrop: backdrop != nil && masksBackdropBehindGlassSurface,
            usesConcentricCorners: true
        )
    }
}
