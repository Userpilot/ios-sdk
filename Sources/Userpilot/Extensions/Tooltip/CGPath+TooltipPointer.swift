//
//  CGPath+TooltipPointer.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Draws the continuous tooltip outline and computes its pointer corner limit.
//

import UIKit

// MARK: - Path Construction

internal extension CGPath {

    /// Builds the card outline with its pointer, drawn clockwise from the top
    /// left.
    ///
    /// Each corner is skipped when the pointer has taken it over, which is what
    /// keeps the outline a single non-self-intersecting loop.
    static func userpilotTooltip(
        around mainRect: CGRect,
        boxCornerRadius: CGFloat,
        pointer: TooltipPointerShape
    ) -> CGPath {
        let path = CGMutablePath()
        let geometry = TooltipPointerGeometry(
            pointer: pointer, mainRect: mainRect, boxCornerRadius: boxCornerRadius)

        if geometry.overridesTopLeftCorner {
            path.move(to: mainRect.origin)
        } else {
            let centre = CGPoint(
                x: mainRect.minX + boxCornerRadius, y: mainRect.minY + boxCornerRadius)
            path.addRelativeArc(
                center: centre, radius: boxCornerRadius, startAngle: .pi, delta: .pi / 2)
        }

        if pointer.edge == .top { path.addPointer(geometry) }

        if !geometry.overridesTopRightCorner {
            let centre = CGPoint(
                x: mainRect.maxX - boxCornerRadius, y: mainRect.minY + boxCornerRadius)
            path.addRelativeArc(
                center: centre, radius: boxCornerRadius, startAngle: 3 * .pi / 2, delta: .pi / 2)
        }

        if pointer.edge == .right { path.addPointer(geometry) }

        if !geometry.overridesBottomRightCorner {
            let centre = CGPoint(
                x: mainRect.maxX - boxCornerRadius, y: mainRect.maxY - boxCornerRadius)
            path.addRelativeArc(
                center: centre, radius: boxCornerRadius, startAngle: 0, delta: .pi / 2)
        }

        if pointer.edge == .bottom { path.addPointer(geometry) }

        if !geometry.overridesBottomLeftCorner {
            let centre = CGPoint(
                x: mainRect.minX + boxCornerRadius, y: mainRect.maxY - boxCornerRadius)
            path.addRelativeArc(
                center: centre, radius: boxCornerRadius, startAngle: .pi / 2, delta: .pi / 2)
        }

        if pointer.edge == .left { path.addPointer(geometry) }

        path.closeSubpath()
        return path
    }
}

private extension CGMutablePath {

    /// Draws the pointer's three sides into the running path.
    ///
    /// A square-tipped pointer is three straight lines. A rounded one uses
    /// tangent arcs, except on a side that has been flattened against a corner —
    /// there is nothing to round on a straight edge, and asking for an arc
    /// produces a visible kink.
    func addPointer(_ geometry: TooltipPointerGeometry) {
        guard geometry.cornerRadius > 0 else {
            addLine(to: geometry.point1)
            addLine(to: geometry.point2)
            addLine(to: geometry.point3)
            return
        }

        if geometry.drawStraightPoint1 {
            addLine(to: geometry.point1)
        } else {
            addArc(
                tangent1End: geometry.point1,
                tangent2End: geometry.point2,
                radius: geometry.cornerRadius)
        }

        addArc(
            tangent1End: geometry.point2,
            tangent2End: geometry.point3,
            radius: geometry.cornerRadius)

        if geometry.drawStraightPoint3 {
            addLine(to: geometry.point3)
        } else {
            addArc(
                tangent1End: geometry.point3,
                tangent2End: geometry.point4,
                radius: geometry.cornerRadius)
        }
    }
}

// MARK: - Pointer Sizing

internal extension CGSize {

    /// Largest tip radius that still draws a continuous pointer.
    ///
    /// Beyond this, the arc rounding the tip grows wider than the arcs rounding
    /// the base corners, so the path doubles back on itself and renders as a
    /// straight notch instead of a point. Solved geometrically: it is the radius
    /// at which the tip arc and the base arc meet exactly, treating `self` as
    /// the pointer's base width by projection height.
    var userpilotMaxPointerCornerRadius: CGFloat {
        let base = CGPoint(x: 0, y: height)
        let tip = CGPoint(x: width / 2, y: 0)
        let angle = atan2(base.y, tip.x)

        let denominator = 1 + 2 * sin(angle - .pi / 2) + (1 / cos(angle))
        guard denominator != 0 else { return 0 }

        return (base.y - tip.y) / denominator
    }
}
