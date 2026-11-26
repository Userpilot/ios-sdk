//
//  StepPresentation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Tooltip presentation config. Layout owns placement policy; the
//  resolved experience theme owns backdrop styling and close-button visibility.
//

import UIKit

// MARK: - Presentation

/// Where and how the tooltip card is drawn relative to its target.
///
/// Render config the Flow projection builds from a tooltip step's `settings`, never a wire model. Gap, edge
/// margin, pointer size and highlight are static SDK values, so they live in `Constants.Theme`'s tooltip values.
internal struct StepPresentation {

    /// Preferred side. Missing lets layout choose; honoured whenever the card fits there.
    let preferredPlacement: TooltipPlacement?

    /// The arrow aiming at the target.
    let pointer: TooltipPointer?

    /// What tapping the target itself does: `"next"` advances like the action button.
    let targetTapAction: String?
}

// MARK: - Pointer

/// The arrow joining the card to its target.
internal struct TooltipPointer {

    /// Whether to draw a pointer at all. Absent means yes.
    ///
    /// Disabling it does more than hide a triangle: it also removes the pointer's
    /// reserved layout space, so the card sits flush at the gap from the target and
    /// the path collapses to a plain rounded rectangle.
    let enabled: Bool?

    /// `true` unless explicitly disabled.
    var isEnabled: Bool {
        enabled ?? true
    }
}
