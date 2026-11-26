//
//  ElementTreeLimits.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Bounds the main-thread cost of one native element-tree capture.
//

/// Limits for the native walk shared by tooltip targeting and Builder capture.
internal enum ElementTreeLimits {
    /// Views one capture visits before it stops descending and keeps what it has walked.
    /// Kept equal to Android's `ElementTreeLimits.MAX_VISITED_NODES`.
    static let maxVisitedNodes = 5_000
}
