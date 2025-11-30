//
//  ExperienceStateManager.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Manages experience flow state, transitions, and active component lifecycle.
//
// swiftlint:disable file_length

import Foundation

// MARK: - TriggerType

/// Type of trigger that initiated an experience.
internal enum TriggerType {
    /// Via triggerExperience() API
    case manual
    /// From screen/track events
    case automatic
    /// Preview mode (QR/deep link)
    case preview
}

// MARK: - ExperienceFlowState

/// Represents the current state of the experience flow in ExperiencesPublisher.
///
/// State transitions:
/// - Idle -> PendingManual/PendingAutomatic/PendingPreview (when experience triggered)
/// - Pending* -> WaitingDelay (when validation passes)
/// - WaitingDelay -> Active (after delay completes)
/// - Active -> ShowingThankYou (for surveys with thank you)
/// - ShowingThankYou -> Idle (after thank you dismissed)
/// - Active -> Idle (when dismissed)
/// - Any -> CachedPending* (when experience triggered while another is active)
internal enum ExperienceFlowState {
    /// No experience is being processed or displayed.
    case idle

    /// Experience triggered manually via triggerExperience() API. Bypasses screen validation.
    case pendingManual(experienceId: String?)

    /// Experience triggered automatically from screen/track events. Requires screen validation.
    case pendingAutomatic(experience: ExperienceContent?)

    /// Experience triggered in preview mode (QR code/deep link). Bypasses all validation and analytics.
    case pendingPreview

    /// Waiting for display delay to complete before showing experience. Delays prevent animation
    /// frame drops from fast socket responses.
    case waitingDelay(triggerType: TriggerType)

    /// Experience is currently being displayed to the user. Holds both the content data and UI
    /// component reference.
    case active(triggerType: TriggerType, content: ExperienceContent)

    /// Thank you message is being displayed after survey completion.
    case showingThankYou

    /// Experience is cached because another experience is currently active. Will be processed when
    /// active experience is dismissed.
    case cachedPendingManual(experienceId: String)

    /// Experience from tracked event cached while another experience is active.
    case cachedPendingAutomatic(experience: ExperienceContent)

    // MARK: - State Checks

    /// Checks if experience was manually triggered.
    func isManualTrigger() -> Bool {
        switch self {
        case .pendingManual, .cachedPendingManual:
            return true
        case .waitingDelay(let triggerType):
            return triggerType == .manual
        case .active(let triggerType, _):
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
        case .waitingDelay(let triggerType):
            return triggerType == .preview
        case .active(let triggerType, _):
            return triggerType == .preview
        default:
            return false
        }
    }

    /// Checks if an experience is currently active, waiting to be shown, or showing thank you.
    /// This includes WaitingDelay to prevent race conditions when multiple events arrive quickly.
    func isActive() -> Bool {
        switch self {
        case .active, .showingThankYou, .waitingDelay:
            return true
        default:
            return false
        }
    }

    /// Checks if there's an actively rendered experience visible to the user.
    /// Unlike isActive(), this excludes WaitingDelay state since that's just preparation, not rendering.
    func isActivelyRendered() -> Bool {
        switch self {
        case .active, .showingThankYou:
            return true
        default:
            return false
        }
    }

    /// Checks if there's a cached experience waiting to be processed.
    func hasCachedExperience() -> Bool {
        switch self {
        case .cachedPendingManual, .cachedPendingAutomatic:
            return true
        default:
            return false
        }
    }

    /// Checks if screen validation should be bypassed.
    func shouldBypassScreenValidation() -> Bool {
        return isManualTrigger() || isPreviewMode()
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
        case .showingThankYou:
            return "ShowingThankYou"
        case .cachedPendingManual(let experienceId):
            return "CachedPendingManual(id=\(experienceId))"
        case .cachedPendingAutomatic:
            return "CachedPendingAutomatic"
        }
    }
}

// MARK: - WeakExperienceReference

/// Wrapper for weak reference to UPExperience
internal class WeakExperienceReference {
    weak var component: UPExperience?

    init(_ component: UPExperience) {
        self.component = component
    }

    func get() -> UPExperience? {
        return component
    }
}

// MARK: - ExperienceStateManaging

/// Protocol defining experience state management behavior.
/// Objects that conform to `ExperienceStateManaging` are responsible for managing
/// experience flow state transitions and providing thread-safe access to the current state.
internal protocol ExperienceStateManaging: AnyObject {

    // MARK: - State Access

    /// Gets the current state
    func getCurrentState() -> ExperienceFlowState

    /// Checks if currently in an active state (Active, ShowingThankYou, or WaitingDelay)
    /// This prevents race conditions by blocking new experiences while one is being shown
    func isActive() -> Bool

    /// Checks if there's an actively rendered experience visible to the user
    /// Unlike isActive(), this excludes WaitingDelay state
    func isActivelyRendered() -> Bool

    /// Checks if in a state that requires screen validation bypass
    func shouldBypassScreenValidation() -> Bool

    /// Checks if currently in preview mode
    func isPreviewMode() -> Bool

    /// Checks if experience was manually triggered
    func isManualTrigger() -> Bool

    /// Checks if there's a cached experience waiting
    func hasCachedExperience() -> Bool

    // MARK: - State Transition Methods

    /// Transitions to Idle state - no experience is being processed
    func markIdle()

    /// Transitions to PendingManual state when manually triggering an experience
    func markManualTrigger(_ experienceId: String?)

    /// Transitions to PendingAutomatic state when experience is triggered from screen/track events
    func markAutomaticTrigger(_ experience: ExperienceContent?)

    /// Transitions to PendingPreview state when entering preview mode
    func markPreviewMode()

    /// Transitions to WaitingDelay state when experience is waiting for display delay
    func markWaitingDelay(_ triggerType: TriggerType)

    /// Transitions to Active state when experience is being displayed
    func markActive(_ triggerType: TriggerType, _ content: ExperienceContent)

    /// Transitions to ShowingThankYou state when thank you message is displayed
    func markShowingThankYou()

    /// Transitions to CachedPendingManual state when manual experience is cached
    func markCachedManual(_ experienceId: String)

    /// Transitions to CachedPendingAutomatic state when automatic experience is cached
    func markCachedAutomatic(_ experience: ExperienceContent)

    // MARK: - Active Experience Component Management

    /// Sets the UI component reference for the currently active experience
    func setActiveComponent(_ component: UPExperience)

    /// Gets the active experience UI component if one exists
    func getActiveComponent() -> UPExperience?

    /// Gets the active experience content if one exists
    func getActiveContent() -> ExperienceContent?

    /// Gets the trigger type of the current active experience
    func getActiveTriggerType() -> TriggerType?

    /// Checks if the active experience component is still alive
    func isActiveComponentAlive() -> Bool

    // MARK: - State Query Helpers

    /// Gets the cached experience ID if in CachedPendingManual state
    func getCachedExperienceId() -> String?

    /// Gets the cached experience content if in CachedPendingAutomatic state
    func getCachedExperienceContent() -> ExperienceContent?

    // MARK: - High-Level Operations

    /// Determines the trigger type from current state and transitions to Active state
    func markActiveFromCurrentState(content: ExperienceContent)

}

// MARK: - ExperienceStateManager

/// Manages the experience flow state transitions and provides thread-safe access to the current
/// state. Encapsulates all state transition logic in one place.
///
/// This class is responsible for:
/// - Managing the atomic state reference
/// - Providing thread-safe state transitions
/// - Logging all state changes for debugging
/// - Managing active experience component references
internal class ExperienceStateManager {

    // MARK: - Properties

    /// SDK logger
    private let logger: Logging

    /**
     * The current experience flow state using thread-safe atomic reference.
     * Starts in Idle state as no experience is being processed.
     */
    private let state: AtomicReference<ExperienceFlowState>

    /**
     * Weak reference to the active experience UI component.
     * Stored separately from state for easier access and management.
     */
    private var activeComponent: WeakExperienceReference?

    // MARK: - Initialization

    init(container: DIContainer) {
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.state = AtomicReference(.idle)
    }

    // MARK: - State Access

    /// Gets the current state
    func getCurrentState() -> ExperienceFlowState {
        return state.value
    }

    /// Checks if currently in an active state (Active, ShowingThankYou, or WaitingDelay)
    /// This prevents race conditions by blocking new experiences while one is being shown
    func isActive() -> Bool {
        return state.value.isActive()
    }

    /// Checks if there's an actively rendered experience visible to the user
    /// Unlike isActive(), this excludes WaitingDelay state
    func isActivelyRendered() -> Bool {
        return state.value.isActivelyRendered()
    }

    /// Checks if in a state that requires screen validation bypass
    func shouldBypassScreenValidation() -> Bool {
        return state.value.shouldBypassScreenValidation()
    }

    /// Checks if currently in preview mode
    func isPreviewMode() -> Bool {
        return state.value.isPreviewMode()
    }

    /// Checks if experience was manually triggered
    func isManualTrigger() -> Bool {
        return state.value.isManualTrigger()
    }

    /// Checks if there's a cached experience waiting
    func hasCachedExperience() -> Bool {
        return state.value.hasCachedExperience()
    }

    // MARK: - State Transition Methods

    /// Transitions to Idle state - no experience is being processed.
    func markIdle() {
        // Clear active component reference
        activeComponent = nil
        state.value = .idle
        logger.info("🎯 Experience state: Idle")
    }

    /**
     * Transitions to PendingManual state when manually triggering an experience.
     *
     * @param experienceId Optional experience ID if known at this point
     */
    func markManualTrigger(_ experienceId: String? = nil) {
        state.value = .pendingManual(experienceId: experienceId)
        logger.info("🎯 Experience state: PendingManual(id=%@)", experienceId ?? "nil")
    }

    /**
     * Transitions to PendingAutomatic state when experience is triggered from screen/track events.
     *
     * @param experience Optional experience content if available
     */
    func markAutomaticTrigger(_ experience: ExperienceContent? = nil) {
        state.value = .pendingAutomatic(experience: experience)
        logger.info("🎯 Experience state: PendingAutomatic")
    }

    /// Transitions to PendingPreview state when entering preview mode.
    func markPreviewMode() {
        state.value = .pendingPreview
        logger.info("🎯 Experience state: PendingPreview")
    }

    /**
     * Transitions to WaitingDelay state when experience is waiting for display delay.
     *
     * @param triggerType The type of trigger that initiated this experience
     */
    func markWaitingDelay(_ triggerType: TriggerType) {
        state.value = .waitingDelay(triggerType: triggerType)
        logger.info("🎯 Experience state: WaitingDelay(%@)", String(describing: triggerType))
    }

    /**
     * Transitions to Active state when experience is being displayed.
     *
     * @param triggerType The type of trigger that initiated this experience
     * @param content The experience content being displayed
     */
    func markActive(_ triggerType: TriggerType, _ content: ExperienceContent) {
        state.value = .active(triggerType: triggerType, content: content)
        logger.info(
            "🎯 Experience state: Active(%@, content=%@)",
            String(describing: triggerType),
            String(describing: type(of: content)))
    }

    /// Transitions to ShowingThankYou state when thank you message is displayed.
    func markShowingThankYou() {
        state.value = .showingThankYou
        logger.info("🎯 Experience state: ShowingThankYou")
    }

    /**
     * Transitions to CachedPendingManual state when manual experience is cached.
     *
     * @param experienceId The ID of the cached experience
     */
    func markCachedManual(_ experienceId: String) {
        state.value = .cachedPendingManual(experienceId: experienceId)
        logger.info("🎯 Experience state: CachedPendingManual(id=%@)", experienceId)
    }

    /**
     * Transitions to CachedPendingAutomatic state when automatic experience is cached.
     *
     * @param experience The cached experience content
     */
    func markCachedAutomatic(_ experience: ExperienceContent) {
        state.value = .cachedPendingAutomatic(experience: experience)
        logger.info("🎯 Experience state: CachedPendingAutomatic")
    }

    // MARK: - Active Experience Component Management

    /**
     * Sets the UI component reference for the currently active experience. Should only be called
     * when in Active state.
     *
     * @param component The experience UI component instance
     * @return true if component was set successfully, false if not in Active state
     */
    func setActiveComponent(_ component: UPExperience) {
        activeComponent = WeakExperienceReference(component)
        logger.info("🎯 Active experience component set: %@", String(describing: type(of: component)))
    }

    /**
     * Gets the active experience UI component if one exists.
     *
     * @return The active UI component, or null if no active experience or component is dead
     */
    func getActiveComponent() -> UPExperience? {
        return activeComponent?.get()
    }

    /**
     * Gets the active experience content if one exists.
     *
     * @return The active experience content, or null if no active experience
     */
    func getActiveContent() -> ExperienceContent? {
        let currentState = state.value
        if case .active(_, let content) = currentState {
            return content
        }
        return nil
    }

    /**
     * Gets the trigger type of the current active experience.
     *
     * @return The trigger type, or null if no active experience
     */
    func getActiveTriggerType() -> TriggerType? {
        let currentState = state.value
        if case .active(let triggerType, _) = currentState {
            return triggerType
        }
        return nil
    }

    /**
     * Checks if the active experience component is still alive (not garbage collected).
     *
     * @return true if component exists and is alive, false otherwise
     */
    func isActiveComponentAlive() -> Bool {
        return activeComponent?.get() != nil
    }

    // MARK: - State Query Helpers

    /**
     * Gets the cached experience ID if in CachedPendingManual state.
     *
     * @return The cached experience ID, or null if not in that state
     */
    func getCachedExperienceId() -> String? {
        let currentState = state.value
        if case .cachedPendingManual(let experienceId) = currentState {
            return experienceId
        }
        return nil
    }

    /**
     * Gets the cached experience content if in CachedPendingAutomatic state.
     *
     * @return The cached experience content, or null if not in that state
     */
    func getCachedExperienceContent() -> ExperienceContent? {
        let currentState = state.value
        if case .cachedPendingAutomatic(let experience) = currentState {
            return experience
        }
        return nil
    }

    // MARK: - High-Level Operations

    /**
     * Determines the trigger type from current state and transitions to Active state. This is a
     * convenience method that combines trigger type detection with state transition.
     *
     * @param content The experience content being displayed
     */
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

// MARK: - ExperienceStateManaging Conformance

extension ExperienceStateManager: ExperienceStateManaging {}
