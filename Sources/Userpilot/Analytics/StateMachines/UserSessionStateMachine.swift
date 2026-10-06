//
//  UserSessionStateMachine.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Tracks identification, user-switch and background context for analytics screen payloads.
//

import Foundation

/// Context retained until a screen ACK or a background refresh settles the session.
internal enum UserSessionState {
    case normal
    case userSwitching
    case awaitingInitialScreen
    case userSwitchingAwaitingScreen
    case backgroundToInitialScreen
}

/// Session transitions and screen decisions used by `AnalyticsPublisher`.
internal protocol UserSessionStateManaging: AnyObject {
    func getCurrentState() -> UserSessionState
    func isUserSwitching() -> Bool
    func markNormal()
    func markUserBackFromBackground()
    func markUserSwitch()
    func markAwaitingInitialScreen()
    func isPostIdentificationContext(_ eventName: String) -> Bool
    func shouldRequestInitialScreenEvent(_ eventsQueueEmpty: Bool, _ hasCurrentScreen: Bool) -> Bool
    func getPostIdentificationScreenConfig(currentStartSession: Bool)
        -> UserSessionStateMachine.PostIdentificationScreenConfig
}

/// Owns session context, not the analytics queue or the current screen.
/// Atomic reads and transitions allow lifecycle and analytics work to share the state safely.
/// The read-modify-write in `markAwaitingInitialScreen` must stay one atomic operation.
internal final class UserSessionStateMachine: UserSessionStateManaging {
    private let logger: Logging
    private let state = AtomicReference<UserSessionState>(.awaitingInitialScreen)

    init(container: DIContainer) {
        logger = container.resolve(Userpilot.Config.self).logger
    }

    func getCurrentState() -> UserSessionState {
        state.value
    }

    func isUserSwitching() -> Bool {
        state.value.isUserSwitching()
    }

    /// A screen ACK, or consuming the pending background refresh, settles session context.
    func markNormal() {
        state.value = .normal
        logger.info("📝 User session state: Normal")
    }

    /// The publisher requests the returning user's current screen after queued work drains.
    func markUserBackFromBackground() {
        state.value = .backgroundToInitialScreen
        logger.info("📝 User session state: BackgroundToInitialScreen")
    }

    /// Preserve the identity boundary until the new user's identify and initial screen are sent.
    func markUserSwitch() {
        state.value = .userSwitching
        logger.info("📝 User session state: UserSwitching")
    }

    /// Preparing identify preserves a pending switch; other states begin ordinary identification.
    /// Logging stays outside the atomic update so logger callbacks cannot re-enter the state lock.
    func markAwaitingInitialScreen() {
        let newState = state.update { current in
            current == .userSwitching ? .userSwitchingAwaitingScreen : .awaitingInitialScreen
        }
        logger.info("📝 User session state: %@", String(describing: newState))
    }

    /// Identify ACKs qualify even after normal tracking; other ACKs only qualify while a screen is due.
    func isPostIdentificationContext(_ eventName: String) -> Bool {
        eventName == Constants.Event.identifyEvent || state.value.needsInitialScreen()
    }

    /// A generated initial screen must not overtake queued analytics or invent an unknown screen.
    func shouldRequestInitialScreenEvent(_ eventsQueueEmpty: Bool, _ hasCurrentScreen: Bool) -> Bool {
        eventsQueueEmpty && hasCurrentScreen
    }

    /// Resolve both flags from one state snapshot. A user switch starts a real screen session;
    /// ordinary identification refreshes content and preserves the publisher's start-session flag.
    func getPostIdentificationScreenConfig(currentStartSession: Bool) -> PostIdentificationScreenConfig {
        let isUserSwitch = state.value.isUserSwitching()
        return PostIdentificationScreenConfig(
            startSession: isUserSwitch || currentStartSession,
            isFakeReload: !isUserSwitch
        )
    }
}

extension UserSessionStateMachine {
    /// Payload decisions for the current identification context; reading them does not consume state.
    struct PostIdentificationScreenConfig {
        let startSession: Bool
        let isFakeReload: Bool
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
