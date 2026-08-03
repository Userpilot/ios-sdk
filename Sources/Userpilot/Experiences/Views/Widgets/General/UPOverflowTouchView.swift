//
//  UPOverflowTouchView.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A container whose subviews stay tappable where they extend past its own edges.
//

import UIKit

/// A container that keeps its subviews tappable even where they extend beyond its own bounds.
///
/// The dismiss buttons are positioned past the trailing edge of their container so they can sit close
/// to the card's edge — `buttonDismiss.trailing == container.trailing + margin`. UIKit's hit-testing
/// walks *down* the hierarchy and asks each view whether a point is inside it before recursing, so
/// anything outside the container is never offered to the button at all: the strip past the edge looks
/// tappable and does nothing. That is 10 pt of a 35 pt dismiss button, and 20 pt of NPS's
/// "Ask me later".
///
/// Overriding `point(inside:with:)` — rather than `hitTest(_:with:)` — is what fixes it with the least
/// behaviour change: the standard hit-test walk is left intact, and only the question of "is this
/// point mine?" is widened to include the subviews that stick out.
internal final class UPOverflowTouchView: UIView {

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) { return true }

        return subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else {
                return false
            }
            return subview.point(inside: convert(point, to: subview), with: event)
        }
    }
}
