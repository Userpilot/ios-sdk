//
//  TooltipLayoutInput.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines TooltipLayoutInput and its related feature models.
//

import UIKit

// MARK: TooltipLayoutInput

/// Everything the placement decision depends on.
internal struct TooltipLayoutInput {

    /// Bounds of the container the card is laid out in.
    let containerBounds: CGRect

    /// Inset from the container edges the card must respect — the SDK's
    /// screen edge margin. `safeBounds` is derived from this.
    let layoutMargins: UIEdgeInsets

    /// The target's rect, in the same space as `containerBounds`.
    let targetRect: CGRect

    /// Size the card's content asked for, when it has measured itself.
    let preferredContentSize: CGSize?

    /// The card's border insets. Added back into the width — see
    /// `contentWidth` for why that is not cosmetic.
    let borderInsets: UIEdgeInsets

    /// How far the pointer projects from the card. `0` when there is none.
    let pointerLength: CGFloat

    /// Gap between the target edge and the card — the SDK's gap.
    let distanceFromTarget: CGFloat

    /// The author's preferred side, honoured whenever it fits.
    let preferredPlacement: TooltipPlacement?
}
