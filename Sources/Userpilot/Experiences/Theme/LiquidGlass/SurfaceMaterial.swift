//
//  SurfaceMaterial.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  How a card / sheet surface paints its background: an opaque fill (today's behaviour)
//  or Liquid Glass tinted with the theme colour.
//

import Foundation

/// The material a themed surface renders with.
///
/// Chrome (dismiss button, floating CTA, popup menus) does not use this — it is gated by
/// availability and the master switch only. This type exists solely for card and sheet
/// backgrounds, which carry the customer's `background_color`.
///
/// `Decodable` is implemented now so the backend `general.material` field can be wired in
/// without touching this type. Decoding is deliberately lenient: an unrecognised string
/// falls back to `.solid`, so a future backend value can never make an installed SDK
/// render something unintended.
internal enum SurfaceMaterial: String, Decodable {

    /// Opaque fill using the theme's `background_color`. The default, and the appearance
    /// every existing integration already has.
    case solid

    /// Liquid Glass, tinted with the theme's `background_color` at a reduced alpha.
    /// Only honoured when the platform and host configuration also permit glass.
    case glass

    /// The value used whenever the theme is silent or supplies something unknown.
    static let `default`: SurfaceMaterial = .solid

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SurfaceMaterial(rawValue: raw.lowercased()) ?? .default
    }
}
