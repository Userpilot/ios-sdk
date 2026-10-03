//
//  ExperienceFlowState.swift
//  Userpilot SDK
//
//  Copyright © 2025 Userpilot. All rights reserved.
//

import Foundation

// MARK: - ExperienceFlowState

/// Represents the current state of the experience flow in ExperiencesPublisher.
internal enum ExperienceFlowState {
    /// No experience is being processed or displayed.
    case idle

    /// Experience triggered manually via triggerExperience() API. Bypasses screen validation.
    case pendingManual(experienceId: String?)

    /// Experience triggered automatically from screen/track events. Requires screen validation.
    case pendingAutomatic(experience: ExperienceContent?)

    /// Experience triggered in preview mode (QR code/deep link). Bypasses analytics.
    case pendingPreview

    /// Waiting for display delay to complete before showing experience.
    case waitingDelay(triggerType: TriggerType)

    /// Experience is currently displayed to the user.
    case active(triggerType: TriggerType, content: ExperienceContent)

    /// Thank you message is displayed after survey completion.
    ///
    /// Carries the preview flag forward: the thank-you state replaces the `active` state that knew
    /// its `triggerType`, so without it a previewed survey's thank-you screen looks like a real one
    /// and publishes real events.
    case showingThankYou(isPreview: Bool)
}

// MARK: - State Checks

extension ExperienceFlowState {

    /// Checks if experience was manually triggered.
    func isManualTrigger() -> Bool {
        switch self {
        case .pendingManual:
            return true
        case .waitingDelay(let triggerType), .active(let triggerType, _):
            return triggerType == .manual
        default:
            return false
        }
    }

    /// Checks if in preview mode.
    func isPreviewMode() -> Bool {
        switch self {
        case .pendingPreview:
            return true
        case .waitingDelay(let triggerType), .active(let triggerType, _):
            return triggerType == .preview
        case .showingThankYou(let isPreview):
            return isPreview
        default:
            return false
        }
    }

    /// Checks if an experience is active, waiting to be shown, or showing thank you.
    func isActive() -> Bool {
        switch self {
        case .active, .showingThankYou, .waitingDelay:
            return true
        default:
            return false
        }
    }

    /// Checks if an experience is visibly rendered to the user.
    func isActivelyRendered() -> Bool {
        switch self {
        case .active, .showingThankYou:
            return true
        default:
            return false
        }
    }

    /// Checks if screen validation should be bypassed.
    func shouldBypassScreenValidation() -> Bool {
        isManualTrigger() || isPreviewMode()
    }
}

// MARK: - CustomStringConvertible

extension ExperienceFlowState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .pendingManual(let experienceId):
            return "PendingManual(id=\(experienceId ?? "nil"))"
        case .pendingAutomatic:
            return "PendingAutomatic"
        case .pendingPreview:
            return "PendingPreview"
        case .waitingDelay(let triggerType):
            return "WaitingDelay(\(triggerType))"
        case .active(let triggerType, let content):
            return "Active(\(triggerType), content=\(type(of: content)))"
        case .showingThankYou(let isPreview):
            return "ShowingThankYou(preview=\(isPreview))"
        }
    }
}
