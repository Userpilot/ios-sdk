//
//  FlowStepSettings.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines a mobile Flow step's settings, its enums and the dismiss `state` wire mapping.
//

import Foundation

// MARK: - FlowStepSettings

/// A Flow step's settings. Older steps can omit placement or send it as null.
/// Unknown enum values reject the whole Flow.
internal struct FlowStepSettings: Codable, Equatable {
    /// Tooltip `auto`/`above`/`below`, modal `top`/`middle`, slideout `bottom`/`center`.
    let position: FlowStepPosition?

    /// Tooltip only: `target_tap` advances on a tap on the target; anything else advances on the button.
    let advanceOn: FlowAdvanceOn?

    /// Read only when a tooltip's target can't be used.
    let fallback: FlowFallback?

    /// Read only when the user or the host app's `endExperience()` closes the step; decides the dismiss
    /// event's `state`.
    let dismissAction: FlowDismissAction?

    /// Replaces the theme backdrop for this step. Same fields as the theme backdrop.
    let backdrop: FlowBackdrop?

    private enum CodingKeys: String, CodingKey {
        case position, fallback, backdrop
        case advanceOn = "advance_on"
        case dismissAction = "dismiss_action"
    }
}

// MARK: - FlowBackdrop

/// A step's backdrop override; each field it sets replaces that field of the merged theme's backdrop.
internal struct FlowBackdrop: Codable, Equatable {
    let enabled: Bool?
    let color: String?
    /// 0–100, like the theme backdrop.
    let opacity: Int?
}

// MARK: - Enums

/// Picks the step's presenter: the tooltip overlay, the carousel (modal) or a slideout.
internal enum FlowStepType: String, Codable {
    case tooltip
    case modal
    case slideout
}

internal extension FlowStepType {
    /// The renderer a Flow segment of this step type uses.
    var presenterType: ContentType {
        switch self {
        case .tooltip: return .tooltip
        case .slideout: return .slideout
        case .modal: return .carousel
        }
    }
}

/// Placement in the renderer selected by the step type.
internal enum FlowStepPosition: String, Codable {
    case auto
    case above
    case below
    case top
    case middle
    case bottom
    case center
}

internal extension FlowStepPosition {
    /// Only explicit tooltip sides override automatic placement.
    var tooltipPlacement: TooltipPlacement? {
        switch self {
        case .above: return .top
        case .below: return .bottom
        default: return nil
        }
    }

    var modalAlignment: ContentAlignmentType? {
        switch self {
        case .top: return .top
        case .middle, .center: return .middle
        default: return nil
        }
    }
}

internal enum FlowAdvanceOn: String, Codable {
    case button
    case targetTap = "target_tap"
}

/// What follows a tooltip step whose target can't be used: skip to the next step, or end the Flow.
internal enum FlowFallback: String, Codable {
    case skipStep = "skip_step"
    case endFlow = "end_flow"
}

/// How the user's close of a step dismisses the Flow; only the dismiss event's `state` differs.
internal enum FlowDismissAction: String, Codable {
    case endFlow = "end_flow"
    case dismissFlowShowNextSession = "dismiss_flow_show_next_session"
    case dismissFlowNeverShowAgain = "dismiss_flow_never_show_again"

    /// The `state` sent on `dismissed_mobile_content`. `nil` means the key is omitted, which
    /// the server routes to its default dismissal; it never sends an empty or null `state`.
    var dismissState: String? {
        switch self {
        case .endFlow: return nil
        case .dismissFlowShowNextSession: return "session"
        case .dismissFlowNeverShowAgain: return "never_show_again"
        }
    }
}
