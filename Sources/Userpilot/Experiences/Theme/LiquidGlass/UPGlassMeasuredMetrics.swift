//
//  UPGlassMeasuredMetrics.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Values the SDK **measured** from real system sheets and alerts, so its own cards can sit
//  alongside them without looking foreign.
//
//  These are not published Apple constants — UIKit does not expose them — so they are the SDK's
//  readings of system visuals at a point in time. That is why the type says "measured": they are
//  accurate rather than authoritative, and they want re-checking on each major iOS release.
//

import UIKit

/// The values UIKit uses for a presented sheet or alert, so the SDK's own overlay can match them.
///
/// The SDK draws experiences in its own `UIWindow` and cannot borrow UIKit's presentation, so these
/// have to be reproduced rather than inherited. Apple documents the *intent* ("use the standard
/// material") but publishes no numbers: there is no public semantic colour for a modal dim, and a
/// sheet's background is a private material.
///
/// So they were measured — a real `.pageSheet` and a real `UIAlertController` presented over a
/// half-white/half-black host, which gives two equations per surface and solves for colour and
/// alpha. Method and raw readings were recorded during the iOS 26 spike (Q9).
///
/// | | light | dark |
/// |---|---|---|
/// | Dim behind a sheet **and** an alert | black @ 0.20 | black @ 0.478 |
/// | Surface | ~rgb(250) @ 69% | ~rgb(39) @ 77% |
/// | Sheet inset from the display edges | 8 pt | 8 pt |
/// | Sheet corners | top ~36 pt, bottom ~53 pt | — |
///
/// The surface values are recorded for reference but **not** reproduced as colours: a translucent
/// measurement is the signature of a material, and untinted `UIGlassEffect(style: .regular)` is
/// that material. Pinning its appearance with `overrideUserInterfaceStyle` is what selects the
/// light or the dark variant.
internal enum UPGlassMeasuredMetrics {

    // MARK: Backdrop

    /// Alpha of the black dim UIKit puts behind a presented sheet or alert in light appearance.
    static let backdropAlphaLight: CGFloat = 0.20

    /// The same in dark appearance. UIKit dims considerably harder here — not a symmetric value,
    /// which is why both are measured rather than assumed.
    static let backdropAlphaDark: CGFloat = 0.478

    /// Apple's dim for the given appearance.
    static func backdropColor(for style: UIUserInterfaceStyle) -> UIColor {
        UIColor.black.withAlphaComponent(
            style == .dark ? backdropAlphaDark : backdropAlphaLight
        )
    }

    // MARK: Sheet geometry

    /// How far UIKit insets a sheet from the display's left, right and bottom edges.
    ///
    /// Measured at 8.0 / 8.7 / 8.3 pt on the three edges — one value, read three times.
    static let sheetEdgeInset: CGFloat = 8

    /// The radius UIKit uses on a sheet's *top* corners, where there is no display corner nearby.
    ///
    /// Measured at ~36 pt against ~53 pt on the same sheet's bottom pair. The asymmetry is not an
    /// inconsistency: a sheet sits against the display at the bottom, where its corners have real
    /// curvature to be concentric with, and against nothing at the top. The SDK matches it — a
    /// single radius large enough for the bottom reads as too round at the top.
    static let sheetTopCornerRadius: CGFloat = 36

    // MARK: Alert geometry

    /// The corner radius `UIAlertController` uses, and so the right default for a centre dialog.
    ///
    /// Measured at 26.7 pt on both the top and bottom corners of a real alert — uniform, unlike a
    /// sheet, because an alert floats away from the display's corners and has nothing to be
    /// concentric with. Its width measured 318 pt on a 402 pt display.
    static let alertCornerRadius: CGFloat = 27

    // MARK: Appearance matching

    /// Which appearance a themed colour is asking for.
    ///
    /// Used when the customer's `background_color` is being replaced by Apple's material: the
    /// colour is discarded, but the *intent* it carried — a dark card or a light one — is kept, by
    /// pinning the material to the matching appearance.
    ///
    /// Uses W3C relative luminance, so a saturated mid-tone resolves the way a person would read
    /// it rather than by naive channel averaging.
    static func interfaceStyle(matching color: UIColor) -> UIUserInterfaceStyle {
        relativeLuminance(of: color) < 0.5 ? .dark : .light
    }

    /// W3C relative luminance, 0 (black) to 1 (white).
    static func relativeLuminance(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            // Pattern colours and the like cannot be decomposed; treat as light, matching the
            // default appearance.
            return 1
        }
        return 0.2126 * linearise(red) + 0.7152 * linearise(green) + 0.0722 * linearise(blue)
    }

    private static func linearise(_ channel: CGFloat) -> CGFloat {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}
