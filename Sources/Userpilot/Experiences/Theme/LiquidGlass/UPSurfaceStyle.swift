//
//  UPSurfaceStyle.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The fully resolved appearance of a card surface: how it is filled, how its backdrop dims, and
//  how its corners are rounded. Produced in one place so containers only apply, never decide.
//

import UIKit

/// How a card's surface should be filled.
internal enum UPSurfaceFill: Equatable {

    /// An opaque themed colour. The pre-iOS 26 appearance, and what every OS below 26 gets.
    case solid(UIColor)

    /// Apple's own sheet material: untinted Liquid Glass, pinned to an appearance.
    ///
    /// The appearance is derived from the theme's colour, so a customer who configured a dark card
    /// still gets a dark one — see ``UPGlassMeasuredMetrics/interfaceStyle(matching:)``.
    case appleGlass(UIUserInterfaceStyle)

    /// Liquid Glass tinted with the customer's colour at the configured strength.
    case tintedGlass(UIColor, alpha: CGFloat)

    /// Whether this fill renders as a material rather than an opaque colour.
    var isGlass: Bool {
        switch self {
        case .solid: return false
        case .appleGlass, .tintedGlass: return true
        }
    }

    /// The appearance the card should be pinned to, or `nil` to follow the host app's.
    ///
    /// Pinning it on the card matters beyond the card itself: the chrome inside — the dismiss button
    /// above all — draws its own glass, and glass renders from the *trait environment*. Without this a
    /// light glass circle sits on a dark card, which is what the dismiss button looked like.
    var appearance: UIUserInterfaceStyle? {
        switch self {
        case .appleGlass(let style): return style
        case .solid, .tintedGlass: return nil
        }
    }
}

/// Everything a container needs in order to paint itself.
///
/// The point of this type is that the decisions — Apple's values or the theme's, glass or solid,
/// masked backdrop or whole — are all made together, in
/// ``GlassCapabilityResolving/surfaceStyle(themeBackground:themeBackdrop:themeBackdropEnabled:appearance:)``,
/// and none of them are re-derived by the views. The bottom sheet and the centre dialog apply the
/// same resolution, which is what stops the two drifting apart.
internal struct UPSurfaceStyle: Equatable {

    /// How the card itself is filled.
    let fill: UPSurfaceFill

    /// The dimming colour behind the card, or `nil` when the card should not dim its background.
    let backdrop: UIColor?

    /// Whether the card's shape should be cut out of the backdrop so the material refracts the
    /// host app instead of the dim.
    let masksBackdrop: Bool

    /// Whether the theme's configured corner radius should be replaced by a display-concentric one.
    let usesConcentricCorners: Bool
}
