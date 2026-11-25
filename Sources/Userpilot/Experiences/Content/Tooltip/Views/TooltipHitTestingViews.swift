//
//  TooltipHitTestingViews.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The two views that decide which touches a tooltip claims.
//
//  A tooltip's card is a rectangle whose *visible* shape is not — it is a
//  rounded box with a pointer sticking out of one edge. Left alone, UIKit would
//  hand it every touch inside that rectangle, including the transparent corners
//  and the strip beside the pointer. These two types narrow that down to the
//  shape the user can actually see, and let everything else fall through to the
//  backdrop behind.
//

import UIKit

// MARK: - Passthrough Wrapper

/// A view that never claims a touch for itself — only its subviews can.
///
/// Wraps the masked card, so a tap the card's outline rejected falls through to
/// the backdrop instead of being absorbed by the shadow wrapper's rectangle.
/// Without it the mask produces dead zones rather than passthrough.
internal final class TooltipPassthroughView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}

// MARK: - Masked Hit Testing

/// A view whose touchable area is its mask, not its bounds.
///
/// The card's bounds are a rectangle, but its visible shape is the tooltip
/// outline — so without this the transparent corners beside the pointer would
/// still swallow taps meant for the backdrop behind them.
internal final class TooltipMaskedView: UIView {

    /// The target hotspot's rect in this view's coordinate space, when one is
    /// active. Taps landing inside it are refused so they reach the backdrop.
    var hotspotRectProvider: (() -> CGRect?)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Refuse a tap the hotspot owns, even when it lands on the card. The card
        // sits above the backdrop, so without this it would absorb the tap and
        // the hotspot would be silently dead wherever the two overlap.
        if let hotspot = hotspotRectProvider?(), hotspot.contains(point) {
            return nil
        }

        guard let maskPath = (layer.mask as? CAShapeLayer)?.path else {
            return super.hitTest(point, with: event)
        }
        return maskPath.contains(point) ? super.hitTest(point, with: event) : nil
    }
}
