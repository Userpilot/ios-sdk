//
//  ResolvedTarget.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines ResolvedTarget and its related feature models.
//

import UIKit

// MARK: - Resolved Target

/// One unambiguous target, ready to anchor a tooltip to.
internal struct ResolvedTarget {

    /// Anchor rect in the admitted window's base coordinate space, measured in points.
    let rect: CGRect

    /// Summed weight of the winning match. Kept for diagnostics — a target that
    /// resolves at 100 (description only) is a much weaker anchor than one at
    /// 20,000, and that is worth seeing in a log.
    let score: Int

    /// Identity of the winning node within this resolution pass. Safe to log:
    /// generated per capture and carrying no host-app content.
    let nodeID: String

    /// The live view that matched.
    ///
    /// Weak because the host owns its lifetime. Each resolution reads a fresh
    /// tree because a reused table-view cell may now represent different content.
    weak var view: UIView?
}
