//
//  CGRect+Tooltip.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Compares two target rects for the stillness check before a tooltip reveals.
//

import CoreGraphics

internal extension CGRect {

    /// Whether every edge is within `tolerance` of the same edge of `other`.
    func userpilotIsNear(_ other: CGRect, tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance &&
            abs(maxX - other.maxX) <= tolerance && abs(maxY - other.maxY) <= tolerance
    }
}
