//
//  UIButtonConfiguration+UPGlass.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Glass button configurations, behind the same compile-time + runtime gate as the rest of
//  the Liquid Glass work.
//
//  Buttons deliberately use Apple's own glass `UIButton.Configuration` factories rather
//  than being wrapped in a `UPGlassEffectView`: the native configurations bring the correct
//  press/highlight behaviour, content insets and morphing for free, which a hand-rolled
//  effect view behind a button would not.
//

import UIKit

/// The glass button variants iOS 26 provides.
internal enum UPGlassButtonStyle {

    /// Frosted and diffuse. **Default for SDK chrome.**
    ///
    /// Preferred over the `clear` variants after the Phase 0 spike found `clear` lenses
    /// strongly enough to compromise a glyph drawn on top of it over busy content.
    /// Measured during the iOS 26 spike (Q1a).
    case glass

    /// Highly transparent, strongly refractive. Only over calm content.
    case clearGlass

    /// Frosted, tinted with the button's `baseBackgroundColor`.
    case prominentGlass

    /// Transparent, tinted with the button's `baseBackgroundColor`.
    case prominentClearGlass
}

@available(iOS 15.0, *)
internal extension UIButton.Configuration {

    /// Returns the matching Liquid Glass configuration, or `nil` when this build or OS
    /// cannot provide one so the caller can fall back to its existing style.
    ///
    /// The `#if compiler(>=6.2)` gate is what lets the SDK keep compiling on Xcode versions
    /// that predate the iOS 26 SDK — Swift does not name-resolve symbols inside an inactive
    /// `#if` branch, so these factories are invisible rather than missing there.
    ///
    /// - Parameter style: Which glass variant to request.
    /// - Returns: A glass configuration, or `nil` when unavailable.
    static func upGlass(_ style: UPGlassButtonStyle) -> UIButton.Configuration? {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            switch style {
            case .glass:
                return .glass()
            case .clearGlass:
                return .clearGlass()
            case .prominentGlass:
                return .prominentGlass()
            case .prominentClearGlass:
                return .prominentClearGlass()
            }
        }
        #endif
        return nil
    }
}
