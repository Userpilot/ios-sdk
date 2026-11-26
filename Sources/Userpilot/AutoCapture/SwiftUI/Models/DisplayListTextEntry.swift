//
//  DisplayListTextEntry.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Stores drawn text geometry and weak source references for live tap hit testing.
//

import UIKit

internal struct DisplayListTextEntry {
    /// Resolved visible text; nil for non-text vector drawings (kept only
    /// to preserve paint-order alignment while pairing layers).
    let title: String?
    /// Frame of the drawn text in display-list (content) space.
    let textFrame: CGRect
    /// The container that visually owns the text (button background, row,
    /// card) in display-list space — what a tap is tested against.
    let hitFrame: CGRect
    /// The layer this text was painted into; used at tap time to map window
    /// coordinates into content space.
    weak var layer: CALayer?
    /// The hosting view whose display list produced this entry; lets a
    /// single-host refresh replace only that host's entries.
    weak var host: UIView?

    /// Returns true when the live layer geometry maps a window tap into this
    /// entry's owning hit frame.
    func containsWindowPoint(_ pointInWindow: CGPoint, in window: UIWindow) -> Bool {
        guard let layer, Self.isVisible(layer, in: window.layer) else { return false }
        let pointInLayer = layer.convert(pointInWindow, from: window.layer)
        let pointInContent = CGPoint(
            x: pointInLayer.x + textFrame.minX,
            y: pointInLayer.y + textFrame.minY
        )
        return hitFrame.contains(pointInContent)
    }

    /// A recycled lazy row keeps its drawing layer but hides it; its
    /// position then overlaps visible rows, so it must never be hit. A layer
    /// no longer attached to `windowLayer` (content SwiftUI swapped out, a
    /// previous screen) is not on screen either, even if its cached frame
    /// still lines up with the tap.
    private static func isVisible(_ layer: CALayer, in windowLayer: CALayer) -> Bool {
        var current: CALayer? = layer
        while let candidate = current {
            if candidate.isHidden || candidate.opacity <= 0 { return false }
            if candidate === windowLayer { return true }
            current = candidate.superlayer
        }
        return false
    }

    /// True when the text appears to sit inside a control/card background,
    /// rather than being a free-standing label or section header.
    var isStyledControlTitleCandidate: Bool {
        let extraHeight = hitFrame.height - textFrame.height
        let extraWidth = hitFrame.width - textFrame.width
        let hasBackground = extraHeight > 2 || extraWidth > 2
        return hasBackground && hitFrame.height <= 90
    }
}
