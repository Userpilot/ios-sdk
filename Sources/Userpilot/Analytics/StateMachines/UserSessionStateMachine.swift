//
//  UserSessionStateMachine.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Owns session-start, identification/background context and Flow error steps for analytics screen payloads.
//

import Foundation

/// Tracks why a screen is due. A successful screen ACK settles this context without changing session-start.
internal enum UserSessionState {
    /// No identification-driven screen is pending; same-screen refreshes retain the session-start flag.
    case normal
    /// A different user was selected. Its identify and first screen must cross the identity boundary.
    case userSwitching
    /// Initial or ordinary identification awaits a screen, generated only after earlier work drains.
    case awaitingInitialScreen
    /// The new user's identify was prepared; its first screen must still start a real session.
    case userSwitchingAwaitingScreen
    /// Background work was handed off. Returning to foreground requests a real current-screen refresh.
    case backgroundToInitialScreen
}

/// Session transitions and screen decisions used by `AnalyticsPublisher`.
internal protocol UserSessionStateManaging: AnyObject {
    var isStartSession: Bool { get }
    func getCurrentState() -> UserSessionState
    func isUserSwitching() -> Bool
    func markNormal()
    func markUserBackFromBackground()
    func beginSession()
    func markAwaitingInitialScreen()
    func acknowledgeScreen()
    func markScreenChanged()
    func resumeSession(isExpired: Bool)
    func resetSessionStart()
    func isPostIdentificationContext(_ eventName: String) -> Bool
    func shouldRequestInitialScreenEvent(_ eventsQueueEmpty: Bool, _ hasCurrentScreen: Bool) -> Bool
    func getPostIdentificationScreenConfig() -> ScreenEventConfig
    func prepareScreen(isFakeReload: Bool) -> ScreenEventConfig
    func recordFlowStepError(flowId: Int, stepId: Int)
    func endFlowRun(_ flowId: Int)
    func flowErrorStepIds() -> Set<Int>
}

/// Owns session-start, identification/background context and the session's Flow error steps.
/// The publisher reports transitions and owns delivery, current-screen metadata and each queued screen's reload intent.
/// One lock protects the related state so payload reads cannot observe half an ACK or session reset.
/// Logging stays outside the lock; publisher queue ordering remains responsible for event delivery.
internal final class UserSessionStateMachine: UserSessionStateManaging {
    private let logger: Logging
    private let lock = NSLock()
    private var state: UserSessionState = .awaitingInitialScreen
    private var startSession = true
    /// Each open Flow run's errored step ids, keyed by Flow id; a run's entry goes when the run ends.
    private var flowErrorSteps: [Int: Set<Int>] = [:]

    init(container: DIContainer) {
        logger = container.resolve(Userpilot.Config.self).logger
    }

    var isStartSession: Bool {
        lock.withLock { startSession }
    }

    func getCurrentState() -> UserSessionState {
        lock.withLock { state }
    }

    func isUserSwitching() -> Bool {
        lock.withLock { state.isUserSwitching() }
    }

    /// Consumes pending background-refresh context without consuming session-start before delivery.
    func markNormal() {
        lock.withLock { state = .normal }
        logger.info("📝 User session state: Normal")
    }

    /// The publisher requests the returning user's current screen after queued work drains.
    func markUserBackFromBackground() {
        lock.withLock { state = .backgroundToInitialScreen }
        logger.info("📝 User session state: BackgroundToInitialScreen")
    }

    /// First identify, logout and a different user establish an initial screen until its successful ACK.
    /// The new session starts with no Flow error steps.
    func beginSession() {
        lock.withLock {
            state = .userSwitching
            startSession = true
            flowErrorSteps.removeAll()
        }
        logger.info("📝 User session state: UserSwitching")
    }

    /// Repeated identifies preserve a pending logout/user-switch boundary until its screen ACK.
    /// Otherwise identify requests a screen refresh without changing session-start.
    func markAwaitingInitialScreen() {
        let newState = lock.withLock {
            state = state.isUserSwitching() ? .userSwitchingAwaitingScreen : .awaitingInitialScreen
            return state
        }
        logger.info("📝 User session state: %@", String(describing: newState))
    }

    /// A matched screen ACK settles identity context. Same-screen reloads retain session-start until navigation.
    func acknowledgeScreen() {
        lock.withLock { state = .normal }
        logger.info("📝 User session state: Normal")
    }

    /// Existing-screen navigation ends session-start; a pending identity boundary still wins at send.
    func markScreenChanged() {
        lock.withLock { startSession = false }
    }

    /// The publisher supplies the inactivity result; storage and clocks stay outside session policy.
    /// An expired session also drops its Flow error steps.
    func resumeSession(isExpired: Bool) {
        lock.withLock {
            startSession = isExpired
            if isExpired { flowErrorSteps.removeAll() }
        }
    }

    /// Explicit reset starts a session without introducing an identification or background transition.
    func resetSessionStart() {
        lock.withLock { startSession = true }
    }

    /// Identify ACKs qualify even after normal tracking; other ACKs only qualify while a screen is due.
    func isPostIdentificationContext(_ eventName: String) -> Bool {
        lock.withLock { eventName == Constants.Event.identifyEvent || state.needsInitialScreen() }
    }

    /// A generated initial screen must not overtake queued analytics or invent an unknown screen.
    func shouldRequestInitialScreenEvent(_ eventsQueueEmpty: Bool, _ hasCurrentScreen: Bool) -> Bool {
        eventsQueueEmpty && hasCurrentScreen
    }

    /// Choose a generated screen's reload intent at enqueue time without changing session-start.
    func getPostIdentificationScreenConfig() -> ScreenEventConfig {
        lock.withLock { screenConfig(isFakeReload: !state.isUserSwitching()) }
    }

    /// Resolve session-start at send time while preserving the queued event's explicit reload intent.
    /// A pending first-user boundary overrides navigation/resume until its successful screen ACK.
    func prepareScreen(isFakeReload: Bool) -> ScreenEventConfig {
        lock.withLock {
            let config = screenConfig(isFakeReload: isFakeReload)
            startSession = config.startSession
            return config
        }
    }

    /// A Flow step's target could not be used; its id goes out in `error_steps` until the run ends.
    func recordFlowStepError(flowId: Int, stepId: Int) {
        lock.withLock { _ = flowErrorSteps[flowId, default: []].insert(stepId) }
    }

    /// The Flow's run ended as the SDK sees it (completed, dismissed or ended by an error), so its error
    /// steps are no longer sent.
    func endFlowRun(_ flowId: Int) {
        lock.withLock { _ = flowErrorSteps.removeValue(forKey: flowId) }
    }

    /// Every open run's error step ids, for the `error_steps` screen metadata.
    func flowErrorStepIds() -> Set<Int> {
        lock.withLock { flowErrorSteps.values.reduce(into: Set<Int>()) { $0.formUnion($1) } }
    }

    /// Called only under the state lock; both reads use the same session snapshot.
    private func screenConfig(isFakeReload: Bool) -> ScreenEventConfig {
        ScreenEventConfig(startSession: state.isUserSwitching() || startSession, isFakeReload: isFakeReload)
    }
}

// MARK: - State predicates and diagnostic names

extension UserSessionState {
    func isUserSwitching() -> Bool {
        self == .userSwitching || self == .userSwitchingAwaitingScreen
    }

    /// Background refresh is handled separately by the publisher after its queue drains.
    func needsInitialScreen() -> Bool {
        self == .awaitingInitialScreen || isUserSwitching()
    }
}

extension UserSessionState: CustomStringConvertible {
    var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .userSwitching:
            return "UserSwitching"
        case .awaitingInitialScreen:
            return "AwaitingInitialScreen"
        case .userSwitchingAwaitingScreen:
            return "UserSwitchingAwaitingScreen"
        case .backgroundToInitialScreen:
            return "BackgroundToInitialScreen"
        }
    }
}
