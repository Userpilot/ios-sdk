//
//  Optional+TooltipPresentation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves tooltip presentation values without depending on renderer state.
//

import UIKit

internal extension Optional where Wrapped == StepPresentation {

    // MARK: Presentation Configuration

    /// The author's preferred side, or `nil` to let the layout engine choose.
    ///
    /// `nil` is a supported payload, not a fallback: the placement algorithm
    /// falls straight through to the best-fitting side.
    var preferredPlacement: TooltipPlacement? {
        self?.preferredPlacement
    }

    /// Pointer dimensions, or `nil` when the pointer is disabled.
    ///
    /// `nil` does more than hide a triangle — it also removes the pointer's
    /// reserved layout space, so the card sits flush at the gap from the target and
    /// its outline collapses to a plain rounded rectangle.
    var pointerSize: CGSize? {
        guard self?.pointer?.isEnabled ?? true else { return nil }
        return CGSize(width: Constants.Theme.tooltipPointerWidth, height: Constants.Theme.tooltipPointerHeight)
    }

    /// Whether tapping the target itself should advance the tooltip.
    ///
    /// With one step this means complete-and-dismiss. It is the only way out of a
    /// tooltip that has neither an action button nor a close button.
    ///
    /// Enabled for any non-empty value, not just the documented `"next"`, and
    /// that direction is deliberate. Failing *closed* on an unrecognised string
    /// is the dangerous choice here: if the hotspot is the only exit, a dashboard
    /// typo would strand the user behind a blocking backdrop. Failing open costs
    /// at worst an extra way to dismiss.
    var hasTargetTapAction: Bool {
        targetTapActionId != nil
    }

    /// The projected `target_tap_action`, trimmed, or `nil` when absent.
    var targetTapActionId: String? {
        let trimmed = self?.targetTapAction?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
