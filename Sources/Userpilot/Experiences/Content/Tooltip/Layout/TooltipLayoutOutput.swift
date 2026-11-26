//
//  TooltipLayoutOutput.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines TooltipLayoutOutput and its related feature models.
//

import UIKit

// MARK: TooltipLayoutOutput

/// Where the card ended up.
internal struct TooltipLayoutOutput {

    /// Card frame in the container's coordinate space.
    let frame: CGRect

    /// The side actually chosen, which may not be the preferred one.
    /// Reported on the `seen` event as `resolved_placement`.
    let placement: TooltipPlacement

    /// How far the card was pushed off centre to stay inside the safe edges.
    /// Drives the pointer's offset along the card's edge.
    let offsetFromCenter: CGFloat

    /// Space to reserve on the card's inner edge so content does not sit
    /// under the pointer. Always on the side facing the target.
    let pointerInset: UIEdgeInsets
}
