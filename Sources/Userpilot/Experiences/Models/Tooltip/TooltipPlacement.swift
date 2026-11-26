//
//  TooltipPlacement.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines TooltipPlacement and its related feature models.
//

import UIKit

// MARK: - Placement

/// Which side of the target the card sits on.
internal enum TooltipPlacement: String {
    case top
    case bottom
    case left
    case right

    /// Whether the placement uses the vertical axis.
    var isVertical: Bool {
        self == .top || self == .bottom
    }
}
