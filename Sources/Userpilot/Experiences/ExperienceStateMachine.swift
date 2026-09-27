//
//  ExperienceStateMachine.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Manages experience flow state, transitions, and active component lifecycle.
//

import Foundation

// MARK: - TriggerType

/// Type of trigger that initiated an experience.
internal enum TriggerType {
    /// Via triggerExperience() API.
    case manual
    /// From screen/track events.
    case automatic
    /// Preview mode (QR/deep link).
    case preview
}

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

// MARK: - WeakExperienceReference

/// Wrapper for weak reference to UPExperience.
internal final class WeakExperienceReference {
    weak var component: UPExperience?

    init(_ component: UPExperience) {
        self.component = component
    }

    func get() -> UPExperience? {
        component
    }
}

// MARK: - ExperienceStateManaging

/// Protocol defining experience state management behavior.
internal protocol ExperienceStateManaging: AnyObject {

    // MARK: - State Access

    func getCurrentState() -> ExperienceFlowState
    func isActive() -> Bool
    func isActivelyRendered() -> Bool
    func shouldBypassScreenValidation() -> Bool
    func isPreviewMode() -> Bool
    func isManualTrigger() -> Bool
    func hasCachedExperience() -> Bool

    // MARK: - State Transition Methods

    func markIdle()
    func markManualTrigger(_ experienceId: String?)
    func markAutomaticTrigger(_ experience: ExperienceContent?)
    func markPreviewMode()
    func markWaitingDelay(_ triggerType: TriggerType)
    func markActive(_ triggerType: TriggerType, _ content: ExperienceContent)
    func markShowingThankYou()
    func markCachedManual(_ experienceId: String)
    func markCachedAutomatic(_ experience: ExperienceContent)
    func clearCachedExperience()

    // MARK: - Active Experience Component Management

    func setActiveComponent(_ component: UPExperience)
    func getActiveComponent() -> UPExperience?
    func getActiveContent() -> ExperienceContent?
    func getActiveTriggerType() -> TriggerType?
    func isActiveComponentAlive() -> Bool

    // MARK: - State Query Helpers

    func getCachedExperienceId() -> String?
    func getCachedExperienceContent() -> ExperienceContent?

    // MARK: - High-Level Operations

    func markActiveFromCurrentState(content: ExperienceContent)
    func processCachedExperience() -> ExperienceStateMachine.CachedExperienceAction
}

// MARK: - ExperienceStateMachine

/// Manages experience flow state transitions and provides thread-safe access to current state.
internal final class ExperienceStateMachine {

    /// Work saved while another experience is being prepared or displayed.
    enum CachedExperienceAction {
        case none
        case triggerManual(experienceId: String)
        case processAutomatic(experience: ExperienceContent)
    }

    // MARK: - Properties

    private let logger: Logging
    private let state: AtomicReference<ExperienceFlowState>
    private var activeComponent: WeakExperienceReference?

    /// A queued request must not replace the current experience's trigger or rendering state.
    private let cachedExperience = AtomicReference<CachedExperienceAction>(.none)

    // MARK: - Initialization

    init(container: DIContainer) {
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.state = AtomicReference(.idle)
    }
}

// MARK: - ExperienceStateManaging

extension ExperienceStateMachine: ExperienceStateManaging {

    // MARK: - State Access

    func getCurrentState() -> ExperienceFlowState {
        state.value
    }

    func isActive() -> Bool {
        state.value.isActive()
    }

    func isActivelyRendered() -> Bool {
        state.value.isActivelyRendered()
    }

    func shouldBypassScreenValidation() -> Bool {
        state.value.shouldBypassScreenValidation()
    }

    func isPreviewMode() -> Bool {
        state.value.isPreviewMode()
    }

    func isManualTrigger() -> Bool {
        state.value.isManualTrigger()
    }

    func hasCachedExperience() -> Bool {
        if case .none = cachedExperience.value {
            return false
        }
        return true
    }

    // MARK: - State Transition Methods

    func markIdle() {
        activeComponent = nil
        state.value = .idle
        logger.info("Experience state: Idle")
    }

    func markManualTrigger(_ experienceId: String? = nil) {
        state.value = .pendingManual(experienceId: experienceId)
        logger.info("Experience state: PendingManual(id=%@)", experienceId ?? "nil")
    }

    func markAutomaticTrigger(_ experience: ExperienceContent? = nil) {
        state.value = .pendingAutomatic(experience: experience)
        logger.info("Experience state: PendingAutomatic")
    }

    func markPreviewMode() {
        state.value = .pendingPreview
        logger.info("Experience state: PendingPreview")
    }

    func markWaitingDelay(_ triggerType: TriggerType) {
        state.value = .waitingDelay(triggerType: triggerType)
        logger.info("Experience state: WaitingDelay(%@)", String(describing: triggerType))
    }

    func markActive(_ triggerType: TriggerType, _ content: ExperienceContent) {
        state.value = .active(triggerType: triggerType, content: content)
        logger.info(
            "Experience state: Active(%@, content=%@)",
            String(describing: triggerType),
            String(describing: type(of: content))
        )
    }

    func markShowingThankYou() {
        // Read the flag before overwriting the state — the outgoing `active`/`waitingDelay` state is
        // the only thing that knows this was a preview.
        let isPreview = state.value.isPreviewMode()
        state.value = .showingThankYou(isPreview: isPreview)
        logger.info("Experience state: ShowingThankYou(preview=%@)", String(isPreview))
    }

    func markCachedManual(_ experienceId: String) {
        cachedExperience.value = .triggerManual(experienceId: experienceId)
        logger.info("Experience state: CachedPendingManual(id=%@)", experienceId)
    }

    func markCachedAutomatic(_ experience: ExperienceContent) {
        let action = cachedExperience.update { current in
            if case .triggerManual = current { return current }
            return .processAutomatic(experience: experience)
        }
        if case .triggerManual = action {
            logger.info("Experience cache: automatic content ignored - manual request has priority")
        } else {
            logger.info("Experience state: CachedPendingAutomatic")
        }
    }

    /// Abandons cached work on logout, screen changes, and preview replacement.
    func clearCachedExperience() {
        cachedExperience.value = .none
    }

    // MARK: - Active Experience Component Management

    func setActiveComponent(_ component: UPExperience) {
        activeComponent = WeakExperienceReference(component)
        logger.info("Active experience component set: %@", String(describing: type(of: component)))
    }

    func getActiveComponent() -> UPExperience? {
        activeComponent?.get()
    }

    func getActiveContent() -> ExperienceContent? {
        if case .active(_, let content) = state.value {
            return content
        }
        return nil
    }

    func getActiveTriggerType() -> TriggerType? {
        if case .active(let triggerType, _) = state.value {
            return triggerType
        }
        return nil
    }

    func isActiveComponentAlive() -> Bool {
        activeComponent?.get() != nil
    }

    // MARK: - State Query Helpers

    func getCachedExperienceId() -> String? {
        if case .triggerManual(let experienceId) = cachedExperience.value {
            return experienceId
        }
        return nil
    }

    func getCachedExperienceContent() -> ExperienceContent? {
        if case .processAutomatic(let experience) = cachedExperience.value {
            return experience
        }
        return nil
    }

    // MARK: - High-Level Operations

    /// Takes the queued request once without changing the active experience's state.
    func processCachedExperience() -> CachedExperienceAction {
        cachedExperience.getAndSet(.none)
    }

    func markActiveFromCurrentState(content: ExperienceContent) {
        let triggerType: TriggerType
        if isManualTrigger() {
            triggerType = .manual
        } else if isPreviewMode() {
            triggerType = .preview
        } else {
            triggerType = .automatic
        }
        markActive(triggerType, content)
    }
}
