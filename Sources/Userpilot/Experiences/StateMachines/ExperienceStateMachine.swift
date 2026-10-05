//
//  ExperienceStateMachine.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
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

    // MARK: - Flow Progress (see ExperienceStateMachine+Flow)

    func beginFlow(_ content: ExperienceContent)
    func beginFlow(steps: [ExperienceStateMachine.FlowStep])
    func hasNextFlowStep() -> Bool
    func advanceFlowStep()
    func clearFlow()

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

    /// Not `private` so `ExperienceStateMachine+Flow` can log its step transitions.
    let logger: Logging
    private let state: AtomicReference<ExperienceFlowState>
    private var activeComponent: WeakExperienceReference?

    /// A queued request must not replace the current experience's trigger or rendering state.
    private let cachedExperience = AtomicReference<CachedExperienceAction>(.none)

    /// Progress through the running flow, or nil when the experience is a single step.
    ///
    /// Kept beside `state` rather than inside it for the same reason as `activeComponent`: a flow
    /// outlives the individual states its steps move through. Read and written only by
    /// `ExperienceStateMachine+Flow`, which is why it is not `private`.
    let flowProgress = AtomicReference<FlowProgress?>(nil)

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
        flowProgress.value = nil
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
