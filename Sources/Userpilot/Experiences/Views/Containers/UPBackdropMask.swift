//
//  UPBackdropMask.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The card-shaped hole cut out of a dimming backdrop, owned as one reusable object.
//
//  Glass refracts whatever is behind it. With a dimming scrim in the way it refracts the scrim and
//  renders muddy grey, so the two effects cancel out. Cutting the card's own shape out of the
//  backdrop lets the glass reach the host app's pixels while the customer's configured backdrop
//  colour and opacity stay exactly as set everywhere the backdrop is still visible.
//
//  Held by the bottom sheet and the centre dialog, which previously carried near-identical copies of
//  this and allocated a fresh `CAShapeLayer` and `UIBezierPath` from every `viewDidLayoutSubviews`.
//  Layout runs repeatedly during presentation, rotation and keyboard changes, and almost none of
//  those passes change the shape.
//

import UIKit

/// The four inputs a backdrop mask is cut from. Comparing them is what lets an unchanged layout
/// pass skip rebuilding an identical path.
internal struct UPBackdropMaskGeometry: Equatable {

    /// The backdrop's own bounds, which the mask fills.
    let bounds: CGRect

    /// The card's frame in the backdrop's coordinate space — the hole.
    let hole: CGRect

    /// The card's top corner radius.
    let topRadius: CGFloat

    /// The card's bottom corner radius. Equal to ``topRadius`` for a uniform shape, which is what a
    /// centre dialog has; a glass bottom sheet's two pairs differ.
    let bottomRadius: CGFloat
}

/// One mask layer and the geometry its path was last cut from.
internal final class UPBackdropMask {

    private let maskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillRule = .evenOdd
        return layer
    }()

    private var geometry: UPBackdropMaskGeometry?

    /// Cuts `geometry`'s hole out of `backdrop`, rebuilding the path only when something moved.
    func apply(to backdrop: UIView, geometry: UPBackdropMaskGeometry) {
        defer {
            if backdrop.layer.mask !== maskLayer { backdrop.layer.mask = maskLayer }
        }
        guard geometry != self.geometry else { return }
        self.geometry = geometry

        let path = UIBezierPath(rect: geometry.bounds)
        path.append(Self.cardPath(geometry))
        path.usesEvenOddFillRule = true
        maskLayer.path = path.cgPath
    }

    /// Removes the mask and forgets its geometry, so the next `apply` rebuilds from scratch.
    func remove(from backdrop: UIView) {
        if backdrop.layer.mask === maskLayer { backdrop.layer.mask = nil }
        geometry = nil
    }

    /// The card's outline, with its top and bottom corners rounded by different amounts.
    ///
    /// `UIBezierPath(roundedRect:cornerRadius:)` is uniform and
    /// `UIBezierPath(roundedRect:byRoundingCorners:cornerRadii:)` applies one radius to whichever
    /// corners it is given, so neither can express a sheet's shape. Each radius is clamped to half
    /// the rect so a large radius on a short card cannot invert the arcs.
    private static func cardPath(_ geometry: UPBackdropMaskGeometry) -> UIBezierPath {
        let rect = geometry.hole
        let limit = min(rect.width / 2, rect.height / 2)
        let top = max(0, min(geometry.topRadius, limit))
        let bottom = max(0, min(geometry.bottomRadius, limit))

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addArc(
            withCenter: CGPoint(x: rect.minX + top, y: rect.minY + top),
            radius: top, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - top, y: rect.minY + top),
            radius: top, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - bottom, y: rect.maxY - bottom),
            radius: bottom, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addArc(
            withCenter: CGPoint(x: rect.minX + bottom, y: rect.maxY - bottom),
            radius: bottom, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.close()
        return path
    }
}
