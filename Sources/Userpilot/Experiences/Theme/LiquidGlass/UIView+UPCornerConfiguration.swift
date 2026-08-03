//
//  UIView+UPCornerConfiguration.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  One helper for rounding corners, so no view has to branch on iOS version itself.
//  Uses `UICornerConfiguration` on iOS 26+ (which unlocks concentric corners, matching
//  Apple's guidance that nested elements should be concentric with their container) and
//  falls back to `layer.cornerRadius` + `maskedCorners` below.
//

import UIKit

// MARK: - Radius

/// How a corner radius should be derived.
internal enum UPCornerRadius {

    /// A literal point value on every OS.
    case fixed(CGFloat)

    /// Fully rounded ends.
    ///
    /// - Parameter legacyFallback: Radius used below iOS 26, where there is no capsule
    ///   primitive. Pass half the view's fixed height. Required rather than derived from
    ///   `bounds`, because corners are usually configured before layout has run.
    case capsule(legacyFallback: CGFloat)

    /// A radius concentric with the superview's, per Apple's shape-continuity guidance.
    ///
    /// - Note: No SDK surface uses this, for two measured reasons — see Q7 and Q8 in
    ///   measured during the iOS 26 spike. It resolves *per corner* against nearby container
    ///   geometry, which on a sheet inset from the display rounds the bottom pair against the
    ///   display and leaves the top pair at the minimum; and its resolved value is not readable,
    ///   which the backdrop mask needs in order to cut a hole of the same shape as the card.
    ///   Concentricity is instead produced from numbers the SDK holds: ``UPDisplayCornerRadius``
    ///   for a card against the display, and `UPButtonView.concentricCornerRadius(fallback:)` for
    ///   a control nested inside a card.
    ///
    /// - Parameters:
    ///   - legacyFallback: Radius used below iOS 26, which has no concentric primitive.
    ///     Normally `parentRadius - inset`.
    ///   - minimum: Floor for the derived radius on iOS 26+.
    case containerConcentric(legacyFallback: CGFloat, minimum: CGFloat? = nil)

    /// The radius in points this case represents, for callers that need to reason about the
    /// shape numerically — such as a nested view computing a concentric radius of its own.
    var nominalValue: CGFloat {
        switch self {
        case .fixed(let value): return value
        case .capsule(let legacyFallback): return legacyFallback
        case .containerConcentric(let legacyFallback, let minimum): return max(legacyFallback, minimum ?? 0)
        }
    }
}

// MARK: - Edges

/// Which corners the radius applies to.
internal enum UPCornerEdges {

    /// All four corners.
    case all

    /// Top two corners only — the bottom-sheet shape.
    case top
}

// MARK: - UIView

/// Storage key for the radius most recently applied by ``UIView/applyCorners(_:edges:clip:)``.
private var upAppliedCornerRadiusKey: UInt8 = 0

internal extension UIView {

    /// The corner radius this view was last given via ``applyCorners(_:edges:clip:)``.
    ///
    /// Recorded separately because there is no way to read it back otherwise: on iOS 26 the
    /// radius lives in `cornerConfiguration`, whose radii are not publicly readable, and
    /// `layer.cornerRadius` stays `0`. Nested elements need it to compute a concentric radius of
    /// their own — see `UPButtonView.concentricCornerRadius(fallback:)`.
    var upAppliedCornerRadius: CGFloat? {
        get { objc_getAssociatedObject(self, &upAppliedCornerRadiusKey) as? CGFloat }
        set {
            objc_setAssociatedObject(
                self, &upAppliedCornerRadiusKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Rounds this view's corners, using the iOS 26 corner configuration API when available.
    ///
    /// - Important: `clip` controls subview clipping on every OS and defaults to `true`, matching
    ///   the behaviour of the code this replaces. With it on, subviews **are** clipped to the
    ///   rounded shape rather than to square bounds — measured in
    ///   measured during the iOS 26 spike, where a full-width bar at the
    ///   card's top edge is trimmed along the corner arc. Pass `false` for views hosting a
    ///   `UIVisualEffectView`, which needs to render its own edge treatment unclipped.
    ///
    /// - Parameters:
    ///   - radius: How to derive the radius.
    ///   - edges: Which corners to round. Defaults to all four.
    ///   - clip: Whether subviews are clipped to the rounded shape. Defaults to `true`.
    func applyCorners(
        _ radius: UPCornerRadius,
        edges: UPCornerEdges = .all,
        clip: Bool = true
    ) {
        clipsToBounds = clip
        upAppliedCornerRadius = radius.nominalValue

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            cornerConfiguration = Self.cornerConfiguration(for: radius, edges: edges)
            return
        }
        #endif

        applyLegacyCorners(radius, edges: edges)
    }

    /// Rounds the top and bottom corners by different amounts.
    ///
    /// This is how UIKit's own sheet is shaped: measured off a real `.pageSheet`, its top corners
    /// are ~36 pt while its bottom pair follows the display's curvature at ~53 pt. A sheet sits
    /// against the display at the bottom and against nothing at the top, so one radius cannot be
    /// right for both.
    ///
    /// Below iOS 26 there are no per-corner radii, so `top` is applied to the top corners alone —
    /// exactly what the sheet did before this existed.
    ///
    /// - Parameters:
    ///   - top: Radius for the two top corners.
    ///   - bottom: Radius for the two bottom corners.
    ///   - clip: Whether subviews are clipped. Defaults to `true`.
    func applyCorners(top: CGFloat, bottom: CGFloat, clip: Bool = true) {
        clipsToBounds = clip
        // The bottom value is the one recorded, because the elements that derive a concentric radius
        // from a sheet — the action button above all — sit at its bottom.
        upAppliedCornerRadius = bottom

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            cornerConfiguration = .corners(
                topLeftRadius: .fixed(top),
                topRightRadius: .fixed(top),
                bottomLeftRadius: .fixed(bottom),
                bottomRightRadius: .fixed(bottom)
            )
            return
        }
        #endif

        applyLegacyCorners(.fixed(top), edges: .top)
    }

    // MARK: Private

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func cornerConfiguration(
        for radius: UPCornerRadius,
        edges: UPCornerEdges
    ) -> UICornerConfiguration {
        switch (radius, edges) {
        case (.capsule, _):
            // A capsule is fully rounded by definition; `edges` cannot narrow it.
            return .capsule()

        case (.fixed(let value), .all):
            return .corners(radius: .fixed(value))

        case (.fixed(let value), .top):
            return .uniformTopRadius(.fixed(value))

        case (.containerConcentric(_, let minimum), .all):
            return .corners(radius: .containerConcentric(minimum: minimum))

        case (.containerConcentric(_, let minimum), .top):
            return .uniformTopRadius(.containerConcentric(minimum: minimum))
        }
    }
    #endif

    /// Pre-iOS 26 path. Mirrors exactly what the SDK did before this helper existed, so the
    /// migration is behaviour-preserving on older systems.
    private func applyLegacyCorners(_ radius: UPCornerRadius, edges: UPCornerEdges) {
        let value: CGFloat
        switch radius {
        case .fixed(let fixed):
            value = fixed
        case .capsule(let legacyFallback):
            value = legacyFallback
        case .containerConcentric(let legacyFallback, _):
            value = legacyFallback
        }

        layer.cornerRadius = value
        switch edges {
        case .all:
            layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        case .top:
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }
}
