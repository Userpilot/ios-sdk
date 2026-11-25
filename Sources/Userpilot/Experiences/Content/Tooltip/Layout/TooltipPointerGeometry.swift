//
//  TooltipPointerGeometry.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Works out where a tooltip pointer's three points land once it has been slid
//  along the card edge — and, when it slides far enough, which of the card's
//  rounded corners it has taken over.
//
//  The corner handling is the whole reason this exists as a type. Get it wrong
//  and the outline self-intersects, which an even-odd fill renders as a hole
//  punched through the card.
//

import UIKit

// MARK: - Pointer Geometry

/// The three points of the pointer triangle, plus which card corners it has
/// displaced.
///
/// The corner logic is the reason this is a type rather than a couple of
/// expressions. As the pointer slides toward a corner there are three regimes:
///
/// * **Clear of the corner** — draw normally, tip centred on the triangle.
/// * **Overlapping the corner arc** — push the pointer back flush against the
///   arc and flatten the side that touches it, so the outline stays a single
///   clean loop instead of the pointer and the arc crossing.
/// * **Past the corner entirely** — the pointer *replaces* the corner. The card
///   corner is skipped and the outline runs straight into the pointer.
///
/// Without the third case the path self-intersects, which an even-odd fill
/// renders as a hole.
internal struct TooltipPointerGeometry {

    // Ordered for a clockwise trace.
    let point1: CGPoint
    let point2: CGPoint
    let point3: CGPoint

    /// Control points just past each end, used as arc tangents.
    let point0: CGPoint
    let point4: CGPoint

    let cornerRadius: CGFloat

    let overridesTopLeftCorner: Bool
    let overridesTopRightCorner: Bool
    let overridesBottomRightCorner: Bool
    let overridesBottomLeftCorner: Bool

    /// Set when that end of the pointer is flush against a corner and so has no
    /// corner left to round.
    let drawStraightPoint1: Bool
    let drawStraightPoint3: Bool

    /// - Parameters:
    ///   - pointer: the pointer to place, already clamped to the edge length.
    ///   - mainRect: the card's box, **in the card's own bounds space with
    ///     origin zero on the pointer's sliding axis**. The leading-corner
    ///     collision test compares against absolute `0` rather than
    ///     `mainRect.minX` / `.minY`, so a non-zero
    ///     origin on that axis would silently stop the collision being detected
    ///     and let the pointer draw straight through the corner arc.
    ///   - boxCornerRadius: the card's corner radius.
    init(pointer: TooltipPointerShape, mainRect: CGRect, boxCornerRadius: CGFloat) {
        self.cornerRadius = pointer.cornerRadius

        let layout: EdgeLayout
        switch pointer.edge {
        case .top:
            layout = Self.topLayout(pointer, mainRect: mainRect, cornerRadius: boxCornerRadius)
        case .bottom:
            layout = Self.bottomLayout(pointer, mainRect: mainRect, cornerRadius: boxCornerRadius)
        case .left:
            layout = Self.leftLayout(pointer, mainRect: mainRect, cornerRadius: boxCornerRadius)
        case .right:
            layout = Self.rightLayout(pointer, mainRect: mainRect, cornerRadius: boxCornerRadius)
        }

        point1 = layout.point1
        point2 = layout.point2
        point3 = layout.point3
        point0 = layout.point0
        point4 = layout.point4
        overridesTopLeftCorner = layout.overridesTopLeftCorner
        overridesTopRightCorner = layout.overridesTopRightCorner
        overridesBottomRightCorner = layout.overridesBottomRightCorner
        overridesBottomLeftCorner = layout.overridesBottomLeftCorner
        drawStraightPoint1 = layout.drawStraightPoint1
        drawStraightPoint3 = layout.drawStraightPoint3
    }

    // MARK: Per-Edge Layout

    /// One edge's resolved points and corner takeovers.
    private struct EdgeLayout {
        let point1: CGPoint
        let point2: CGPoint
        let point3: CGPoint
        let point0: CGPoint
        let point4: CGPoint
        var overridesTopLeftCorner = false
        var overridesTopRightCorner = false
        var overridesBottomRightCorner = false
        var overridesBottomLeftCorner = false
        var drawStraightPoint1 = false
        var drawStraightPoint3 = false
    }

    /// Pointer on the card's top edge, aiming up at a target above it.
    private static func topLayout(
        _ pointer: TooltipPointerShape,
        mainRect: CGRect,
        cornerRadius: CGFloat
    ) -> EdgeLayout {
        let bounds = CGRect(
            x: mainRect.midX - pointer.size.width / 2 + pointer.offset,
            y: mainRect.minY - pointer.size.height,
            width: pointer.size.width,
            height: pointer.size.height
        )
        let resolved = resolveHorizontal(
            bounds: bounds, mainRect: mainRect, boxCornerRadius: cornerRadius)

        return EdgeLayout(
            point1: CGPoint(x: resolved.bounds.minX, y: resolved.bounds.maxY),
            point2: CGPoint(x: resolved.tip, y: resolved.bounds.minY),
            point3: CGPoint(x: resolved.bounds.maxX, y: resolved.bounds.maxY),
            point0: CGPoint(x: mainRect.minX + cornerRadius, y: resolved.bounds.maxY),
            point4: CGPoint(x: mainRect.maxX - cornerRadius, y: resolved.bounds.maxY),
            overridesTopLeftCorner: resolved.overridesLeading,
            overridesTopRightCorner: resolved.overridesTrailing,
            drawStraightPoint1: resolved.flushLeading,
            drawStraightPoint3: resolved.flushTrailing
        )
    }

    /// Pointer on the card's bottom edge, aiming down at a target below it.
    ///
    /// The flush flags are swapped relative to `.top` because the bottom edge is
    /// traced right-to-left in a clockwise path, so point1 is the *trailing* end.
    private static func bottomLayout(
        _ pointer: TooltipPointerShape,
        mainRect: CGRect,
        cornerRadius: CGFloat
    ) -> EdgeLayout {
        let bounds = CGRect(
            x: mainRect.midX - pointer.size.width / 2 + pointer.offset,
            y: mainRect.maxY,
            width: pointer.size.width,
            height: pointer.size.height
        )
        let resolved = resolveHorizontal(
            bounds: bounds, mainRect: mainRect, boxCornerRadius: cornerRadius)

        return EdgeLayout(
            point1: CGPoint(x: resolved.bounds.maxX, y: resolved.bounds.minY),
            point2: CGPoint(x: resolved.tip, y: resolved.bounds.maxY),
            point3: CGPoint(x: resolved.bounds.minX, y: resolved.bounds.minY),
            point0: CGPoint(x: mainRect.maxX - cornerRadius, y: resolved.bounds.minY),
            point4: CGPoint(x: mainRect.minX + cornerRadius, y: resolved.bounds.minY),
            overridesBottomRightCorner: resolved.overridesTrailing,
            overridesBottomLeftCorner: resolved.overridesLeading,
            drawStraightPoint1: resolved.flushTrailing,
            drawStraightPoint3: resolved.flushLeading
        )
    }

    /// Pointer on the card's left edge, aiming left at a target beside it.
    private static func leftLayout(
        _ pointer: TooltipPointerShape,
        mainRect: CGRect,
        cornerRadius: CGFloat
    ) -> EdgeLayout {
        let bounds = CGRect(
            x: mainRect.minX - pointer.size.height,
            y: mainRect.midY - pointer.size.width / 2 + pointer.offset,
            width: pointer.size.height,
            height: pointer.size.width
        )
        let resolved = resolveVertical(
            bounds: bounds, mainRect: mainRect, boxCornerRadius: cornerRadius)

        return EdgeLayout(
            point1: CGPoint(x: resolved.bounds.maxX, y: resolved.bounds.maxY),
            point2: CGPoint(x: resolved.bounds.minX, y: resolved.tip),
            point3: CGPoint(x: resolved.bounds.maxX, y: resolved.bounds.minY),
            point0: CGPoint(x: resolved.bounds.maxX, y: mainRect.maxY - cornerRadius),
            point4: CGPoint(x: resolved.bounds.maxX, y: mainRect.minY + cornerRadius),
            overridesTopLeftCorner: resolved.overridesLeading,
            overridesBottomLeftCorner: resolved.overridesTrailing,
            drawStraightPoint1: resolved.flushTrailing,
            drawStraightPoint3: resolved.flushLeading
        )
    }

    /// Pointer on the card's right edge, aiming right at a target beside it.
    private static func rightLayout(
        _ pointer: TooltipPointerShape,
        mainRect: CGRect,
        cornerRadius: CGFloat
    ) -> EdgeLayout {
        let bounds = CGRect(
            x: mainRect.maxX,
            y: mainRect.midY - pointer.size.width / 2 + pointer.offset,
            width: pointer.size.height,
            height: pointer.size.width
        )
        let resolved = resolveVertical(
            bounds: bounds, mainRect: mainRect, boxCornerRadius: cornerRadius)

        return EdgeLayout(
            point1: CGPoint(x: resolved.bounds.minX, y: resolved.bounds.minY),
            point2: CGPoint(x: resolved.bounds.maxX, y: resolved.tip),
            point3: CGPoint(x: resolved.bounds.minX, y: resolved.bounds.maxY),
            point0: CGPoint(x: resolved.bounds.minX, y: mainRect.minY + cornerRadius),
            point4: CGPoint(x: resolved.bounds.minX, y: mainRect.maxY - cornerRadius),
            overridesTopRightCorner: resolved.overridesLeading,
            overridesBottomRightCorner: resolved.overridesTrailing,
            drawStraightPoint1: resolved.flushLeading,
            drawStraightPoint3: resolved.flushTrailing
        )
    }

    // MARK: Corner Resolution

    /// Where the pointer ended up after being nudged clear of the card corners.
    private struct Resolved {
        let bounds: CGRect
        /// Position of the tip along the sliding axis.
        let tip: CGFloat
        let overridesLeading: Bool
        let overridesTrailing: Bool
        let flushLeading: Bool
        let flushTrailing: Bool
    }

    /// Corner resolution for a pointer sliding horizontally (top / bottom edge).
    private static func resolveHorizontal(
        bounds: CGRect,
        mainRect: CGRect,
        boxCornerRadius: CGFloat
    ) -> Resolved {
        var bounds = bounds
        let trailingLimit = mainRect.maxX - bounds.width

        if bounds.minX < boxCornerRadius {
            let overrides = bounds.minX < 0
            bounds.origin.x = overrides ? 0 : boxCornerRadius
            return Resolved(
                bounds: bounds, tip: bounds.minX,
                overridesLeading: overrides, overridesTrailing: false,
                flushLeading: true, flushTrailing: false)
        }

        if bounds.minX > trailingLimit - boxCornerRadius {
            let overrides = bounds.minX > trailingLimit
            bounds.origin.x = overrides ? trailingLimit : trailingLimit - boxCornerRadius
            return Resolved(
                bounds: bounds, tip: bounds.maxX,
                overridesLeading: false, overridesTrailing: overrides,
                flushLeading: false, flushTrailing: true)
        }

        return Resolved(
            bounds: bounds, tip: bounds.midX,
            overridesLeading: false, overridesTrailing: false,
            flushLeading: false, flushTrailing: false)
    }

    /// Corner resolution for a pointer sliding vertically (left / right edge).
    private static func resolveVertical(
        bounds: CGRect,
        mainRect: CGRect,
        boxCornerRadius: CGFloat
    ) -> Resolved {
        var bounds = bounds
        let trailingLimit = mainRect.maxY - bounds.height

        if bounds.minY < boxCornerRadius {
            let overrides = bounds.minY < 0
            bounds.origin.y = overrides ? 0 : boxCornerRadius
            return Resolved(
                bounds: bounds, tip: bounds.minY,
                overridesLeading: overrides, overridesTrailing: false,
                flushLeading: true, flushTrailing: false)
        }

        if bounds.minY > trailingLimit - boxCornerRadius {
            let overrides = bounds.minY > trailingLimit
            bounds.origin.y = overrides ? trailingLimit : trailingLimit - boxCornerRadius
            return Resolved(
                bounds: bounds, tip: bounds.maxY,
                overridesLeading: false, overridesTrailing: overrides,
                flushLeading: false, flushTrailing: true)
        }

        return Resolved(
            bounds: bounds, tip: bounds.midY,
            overridesLeading: false, overridesTrailing: false,
            flushLeading: false, flushTrailing: false)
    }
}
