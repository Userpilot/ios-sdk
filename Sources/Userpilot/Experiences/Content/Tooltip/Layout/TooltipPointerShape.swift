//
//  TooltipPointerShape.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Builds the tooltip card outline — rounded box *and* pointer — as **one
//  continuous path**.
//
//  One path rather than a box plus a triangle is the whole point. It means one
//  mask, one shadow path, and one border stroke, so there is no seam where the
//  pointer meets the card and no double-drawn shadow along that join. Drawing
//  them separately looks fine until a border or shadow is applied, at which
//  point the join is visible on every tooltip.
//
//  The fiddly part is what happens when the pointer slides far enough along the
//  card edge to reach a rounded corner — see `TooltipPointerGeometry`, which
//  resolves it by taking the corner over rather than letting the two shapes
//  overlap.
//

import UIKit

// MARK: - Pointer Description

/// A pointer to draw on one edge of the card.
internal struct TooltipPointerShape {

    /// Which edge of the card the pointer sits on.
    ///
    /// The *opposite* of the card's placement: a card placed above its target
    /// points downward.
    enum Edge {
        case top
        case bottom
        case left
        case right

        /// The pointer edge for a card placed on `placement`.
        init(placement: TooltipPlacement) {
            switch placement {
            case .top: self = .bottom
            case .bottom: self = .top
            case .left: self = .right
            case .right: self = .left
            }
        }
    }

    let edge: Edge

    /// `width` is the base along the card edge; `height` is how far it projects.
    let size: CGSize

    /// Rounding at the pointer's tip.
    let cornerRadius: CGFloat

    /// How far along the edge the pointer slides from centre, so it keeps
    /// aiming at the target after the card was clamped to a screen edge.
    let offset: CGFloat
}
