//
//  TooltipAvailableSpace.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  How much room a tooltip card has on each side of its target, and therefore
//  which sides it could actually be placed on.
//
//  Stage 1 of the two-stage placement decision in `TooltipLayoutEngine`. Split
//  out because it is the part with the subtle arithmetic — the clamp order, and
//  counting the pointer as part of what a side has to hold.
//

import UIKit

// MARK: - Available Space

/// Room left on each side of the target once the card and its pointer are
/// accounted for.
internal struct TooltipAvailableSpace {

    // MARK: Raw Space

    /// Distance from the safe edge to where the card's near edge would sit on
    /// that side — the gap is already subtracted, so this is room for the card,
    /// not distance to the target.
    let above: CGFloat
    let below: CGFloat
    let before: CGFloat
    let after: CGFloat

    // MARK: Excess

    /// What is left over once the card and pointer are placed on that side.
    /// Positive means the side is viable.
    let excessAbove: CGFloat
    let excessBelow: CGFloat
    let excessBefore: CGFloat
    let excessAfter: CGFloat

    /// Space the pointer needs along the chosen axis.
    let pointerLength: CGFloat

    /// The card's border height, needed again when flooring a shrunk card.
    let borderHeight: CGFloat

    // MARK: Initialization

    /// Measures every side against a target.
    ///
    /// - Parameters:
    ///   - targetRect: the element being pointed at.
    ///   - safeBounds: container bounds already inset by the edge margin.
    ///   - cardSize: the card's size before the pointer is added.
    ///   - distance: gap between the target edge and the card.
    ///   - pointerLength: how far the pointer projects, or `0`.
    ///   - borderInsets: the card's border insets.
    init(
        targetRect: CGRect,
        safeBounds: CGRect,
        cardSize: CGSize,
        distance: CGFloat,
        pointerLength: CGFloat,
        borderInsets: UIEdgeInsets
    ) {
        // Clamping the target edge into the safe bounds **before** subtracting
        // is what stops a partly off-screen anchor producing nonsense. Without
        // it, a target scrolled above the screen yields a negative gap and every
        // comparison downstream becomes meaningless — the card would be placed
        // against a side that does not exist.
        let verticalLimits = safeBounds.minY...safeBounds.maxY
        let horizontalLimits = safeBounds.minX...safeBounds.maxX

        above = (targetRect.minY - distance).clamped(to: verticalLimits) - safeBounds.minY
        below = safeBounds.maxY - (targetRect.maxY + distance).clamped(to: verticalLimits)
        before = (targetRect.minX - distance).clamped(to: horizontalLimits) - safeBounds.minX
        after = safeBounds.maxX - (targetRect.maxX + distance).clamped(to: horizontalLimits)

        self.pointerLength = pointerLength
        self.borderHeight = borderInsets.top + borderInsets.bottom

        // The pointer counts toward what a side must hold, so a side with room
        // for the card but not its pointer is correctly rejected rather than
        // producing a card with its point clipped off.
        excessAbove = above - (cardSize.height + pointerLength)
        excessBelow = below - (cardSize.height + pointerLength)
        excessBefore = before - (cardSize.width + pointerLength)
        excessAfter = after - (cardSize.width + pointerLength)
    }

    // MARK: Queries

    /// Whether either vertical side can hold the card.
    var hasVerticalRoom: Bool { excessAbove > 0 || excessBelow > 0 }

    /// Whether either horizontal side can hold the card.
    var hasHorizontalRoom: Bool { excessBefore > 0 || excessAfter > 0 }

    /// The roomier vertical side. Also the shrink-to-fit fallback.
    var bestVertical: TooltipPlacement { excessAbove > excessBelow ? .top : .bottom }

    /// The roomier horizontal side.
    var bestHorizontal: TooltipPlacement { excessBefore > excessAfter ? .left : .right }

    /// Whether `placement` has room for the card and its pointer.
    func fits(_ placement: TooltipPlacement) -> Bool {
        excess(for: placement) > 0
    }

    /// Raw space available along `placement`'s axis, before the card is sized.
    func space(for placement: TooltipPlacement) -> CGFloat {
        switch placement {
        case .top: return above
        case .bottom: return below
        case .left: return before
        case .right: return after
        }
    }

    /// Space left over on `placement` once the card and pointer are placed.
    func excess(for placement: TooltipPlacement) -> CGFloat {
        switch placement {
        case .top: return excessAbove
        case .bottom: return excessBelow
        case .left: return excessBefore
        case .right: return excessAfter
        }
    }
}
