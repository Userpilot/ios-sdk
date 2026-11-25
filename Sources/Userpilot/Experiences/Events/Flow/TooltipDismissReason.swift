//
//  TooltipDismissReason.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines why a tooltip overlay closes and which reasons dismiss its Flow step.
//

import Foundation

// MARK: - Dismiss Reason

/// Why a tooltip overlay is closing. Local only: a reason that `dismissesStep` ends the Flow step as
/// dismissed (`dismissed_mobile_content`); every other reason is an SDK-driven close, which sends
/// nothing.
internal enum TooltipDismissReason {

    /// The user tapped the close button.
    case closeButton

    /// The host app's `endExperience()` closed a step that was seen. It ends the step like the user's
    /// close, as it does a modal or slideout step.
    case hostClose

    /// A target that had been resolved and visible went away for good.
    case targetLost

    /// The SDK closed the tooltip. Covers every SDK-driven close (a screen change, a logout, a QR
    /// preview, Builder capture mode), a reset, a superseding experience and a host close of a step
    /// never revealed, because those close paths carry no step outcome.
    case sdkReset

    /// Whether this close ends the step as `dismissed_mobile_content`.
    var dismissesStep: Bool {
        self == .closeButton || self == .hostClose
    }
}
