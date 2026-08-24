//
//  DebuggerFabDocking.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

/// Pure FAB placement: trailing + 72% down initially, snap to nearer edge, clamp to safe area.
enum DebuggerFabDocking {
    static let size = DebuggerTheme.fabSize
    static let margin = DebuggerTheme.fabMargin

    static func initialOrigin(bounds: CGRect, safeArea: UIEdgeInsets) -> CGPoint {
        let box = clampBox(bounds: bounds, safeArea: safeArea)
        let originY = (bounds.height * DebuggerTheme.fabInitialYFraction) - size
        return CGPoint(x: box.maxX, y: min(max(originY, box.minY), box.maxY))
    }

    static func snappedOrigin(current: CGPoint, bounds: CGRect, safeArea: UIEdgeInsets) -> CGPoint {
        let box = clampBox(bounds: bounds, safeArea: safeArea)
        let centerX = current.x + (size / 2)
        let originX = centerX < bounds.midX ? box.minX : box.maxX
        let originY = min(max(current.y, box.minY), box.maxY)
        return CGPoint(x: originX, y: originY)
    }

    static func dockedOrigin(
        dockedRight: Bool,
        originY: CGFloat,
        bounds: CGRect,
        safeArea: UIEdgeInsets
    ) -> CGPoint {
        let box = clampBox(bounds: bounds, safeArea: safeArea)
        return CGPoint(
            x: dockedRight ? box.maxX : box.minX,
            y: min(max(originY, box.minY), box.maxY)
        )
    }

    private static func clampBox(bounds: CGRect, safeArea: UIEdgeInsets) -> CGRect {
        let minX = bounds.minX + safeArea.left + margin
        let minY = bounds.minY + safeArea.top + margin
        let maxX = bounds.maxX - safeArea.right - size - margin
        let maxY = bounds.maxY - safeArea.bottom - size - margin
        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 0),
            height: max(maxY - minY, 0)
        )
    }
}
