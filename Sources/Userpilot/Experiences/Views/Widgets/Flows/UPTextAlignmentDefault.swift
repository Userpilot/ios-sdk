//
//  UPTextAlignmentDefault.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  What a flow's text falls back to when the backend sends no `text_align`. Carried as one value
//  so the two inputs — whether Liquid Glass is in use, and whether the locale is right-to-left —
//  travel together through the widgets between a flow and its labels.
//

import UIKit

/// The alignment a flow's text takes when its content does not specify one.
///
/// Only the *absent* case is decided here. An explicit `text_align` from the backend is honoured
/// exactly as it always was — including its absolute reading, where `"left"` means the left edge on
/// right-to-left content too. Nothing an author set in the dashboard moves.
///
/// | `text_align` | Glass on, LTR | Glass on, RTL | Glass off |
/// |---|---|---|---|
/// | absent     | left    | right   | **centred** |
/// | `"left"`   | left    | left    | left    |
/// | `"right"`  | right   | right   | right   |
/// | `"center"` | centred | centred | centred |
///
/// Carried as one value rather than two loose booleans so the pair cannot be threaded
/// half-applied, and passed explicitly at every call site rather than defaulted, so adding one
/// forces a choice of column instead of silently landing in the last.
///
/// Scope is the flow experiences: carousel and slide-out headers, paragraphs, and the text half of
/// an icon-text row. NPS and surveys lay their text out through `UPTitleDescriptionView`, which has
/// always resolved its own leading edge and is untouched.
///
/// Mirrors `UPTextAlignmentDefault` in the Android SDK, where the same table is gated on that
/// platform's equivalent config flag. Keep the two in step.
internal struct UPTextAlignmentDefault {

    /// Whether text should start at the leading edge rather than being centred.
    ///
    /// Comes from `allowsGlass(for: .chrome)`, which is the availability check plus
    /// `Config.liquidGlass(_:)`. So a host that turns Liquid Glass off, and every host below
    /// iOS 26, keeps the centred text it has today — the flag is the whole of the opt-in.
    let prefersLeading: Bool

    /// Whether the experience's locale is right-to-left, from `localeCode.isRTL`.
    ///
    /// The experience's own locale, not the device's: a flow authored in Arabic reads right-to-left
    /// inside an English app.
    let isRTL: Bool

    /// The alignment to use.
    ///
    /// Resolved to an absolute edge rather than `.natural`, deliberately. `NSTextAlignment.natural`
    /// on a `UILabel` derives its direction from the text's own characters, not from the layout
    /// direction — so an Arabic string in an English app aligns right and a Latin-script string in
    /// an Arabic one aligns left, neither of which follows the experience's locale. `isRTL` is the
    /// answer the flow already has, so it is the one used.
    var resolved: NSTextAlignment {
        guard prefersLeading else { return .center }
        return isRTL ? .right : .left
    }

    /// The default for a flow, given what its resolver allows and the locale its content declares.
    ///
    /// - Parameters:
    ///   - resolver: The experience's glass capability resolver, or `nil` when it has none.
    ///   - isRTL: Whether the experience's locale is right-to-left.
    static func forFlow(resolver: GlassCapabilityResolving?, isRTL: Bool) -> UPTextAlignmentDefault {
        UPTextAlignmentDefault(
            prefersLeading: resolver?.allowsGlass(for: .chrome) ?? false,
            isRTL: isRTL
        )
    }
}
