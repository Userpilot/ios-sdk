//
//  UserSessionStateManager.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Manages user session lifecycle states for analytics and screen tracking.
//

import Foundation

// MARK: - UserSessionState

/// Represents the various states of a user session in the Userpilot SDK.
/// This enum models the lifecycle of user identification and screen tracking.
internal enum UserSessionState {
    /// Normal operation state - user is identified and initial screen has been sent.
    case normal

    /// User switching state - a user switch operation is in progress, socket closed with queued
    /// events. Waiting for identify event to be processed.
    case userSwitching

    /// Awaiting initial screen state - user has been identified but initial screen event has not
    /// been sent yet. This is for the first-time user identification.
    case awaitingInitialScreen

    /// User switching with awaiting initial screen state - combines both conditions:
    /// 1. User switch is in progress (affects startSession=true, fake_reload=false)
    /// 2. Awaiting initial screen for the new user (affects screen event triggering)
    case userSwitchingAwaitingScreen

    /// Coming from background state - need to request fake reload screen event.
    case backgroundToInitialScreen

    /// Checks if a user switch operation is currently in progress.
    func isUserSwitching() -> Bool {
        switch self {
        case .userSwitching, .userSwitchingAwaitingScreen:
            return true
        default:
            return false
        }
    }

    /// Checks if an initial screen event needs to be sent.
    func needsInitialScreen() -> Bool {
        switch self {
        case .awaitingInitialScreen, .userSwitching, .userSwitchingAwaitingScreen:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

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

// MARK: - UserSessionStateManaging

/// Protocol defining user session state management behavior.
/// Objects that conform to `UserSessionStateManaging` are responsible for managing
/// user session state transitions and providing thread-safe access to the current state.
internal protocol UserSessionStateManaging: AnyObject {

    // MARK: - State Access

    /// Gets the current state
    func getCurrentState() -> UserSessionState

    /// Checks if a user switch operation is currently in progress
    func isUserSwitching() -> Bool

    /// Checks if an initial screen event needs to be sent
    func needsInitialScreen() -> Bool

    /// Checks if currently in Normal state
    func isNormal() -> Bool

    /// Checks if currently in AwaitingInitialScreen state
    func isAwaitingInitialScreen() -> Bool

    /// Checks if currently in UserSwitchingAwaitingScreen state
    func isUserSwitchingAwaitingScreen() -> Bool

    // MARK: - State Transition Methods

    /// Transitions to Normal state after initial screen event is sent
    func markNormal()

    /// Transitions to BackgroundToInitialScreen state when the app returns from background
    func markUserBackFromBackground()

    /// Transitions to UserSwitching state when a user switch is detected
    func markUserSwitch()

    /// Transitions to AwaitingInitialScreen or UserSwitchingAwaitingScreen state
    func markAwaitingInitialScreen()

    // MARK: - High-Level Operations

    /// Determines if this is a post-identification scenario requiring a screen event
    func isPostIdentificationContext(_ eventName: String) -> Bool

    /// Determines if an initial screen event should be requested
    func shouldRequestInitialScreenEvent(_ eventsQueueEmpty: Bool, _ hasCurrentScreen: Bool) -> Bool

    /// Gets the configuration for post-identification screen event
    func getPostIdentificationScreenConfig(currentStartSession: Bool)
        -> UserSessionStateManager.PostIdentificationScreenConfig

    /// Gets the post-identification start session configuration
    func getPostIdentificationStartSessionConfig(currentStartSession: Bool) -> Bool

    /// Gets the post-identification fake reload configuration
    func getPostIdentificationFakeReloadConfig() -> Bool
}

// MARK: - UserSessionStateManager

/// Manages the user session state transitions and provides thread-safe access to the current state.
/// Encapsulates all state transition logic in one place.
///
/// This class is responsible for:
/// - Managing the atomic state reference
/// - Providing thread-safe state transitions
/// - Logging all state changes for debugging
/// - Determining post-identification context and screen requirements
internal class UserSessionStateManager {

    // MARK: - Properties

    /// SDK logger.
    private let logger: Logging

    /**
     * The current user session state using thread-safe atomic reference.
     * Starts in AwaitingInitialScreen state as no user has been identified yet.
     */
    private let state: AtomicReference<UserSessionState>

    // MARK: - Initialization

    init(container: DIContainer) {
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.state = AtomicReference(.awaitingInitialScreen)
    }

    // MARK: - State Access

    /// Gets the current state
    func getCurrentState() -> UserSessionState {
        return state.value
    }

    /// Checks if a user switch operation is currently in progress
    func isUserSwitching() -> Bool {
        return state.value.isUserSwitching()
    }

    /// Checks if an initial screen event needs to be sent
    func needsInitialScreen() -> Bool {
        return state.value.needsInitialScreen()
    }

    /// Checks if currently in Normal state
    func isNormal() -> Bool {
        if case .normal = state.value {
            return true
        }
        return false
    }

    /// Checks if currently in AwaitingInitialScreen state
    func isAwaitingInitialScreen() -> Bool {
        if case .awaitingInitialScreen = state.value {
            return true
        }
        return false
    }

    /// Checks if currently in UserSwitchingAwaitingScreen state
    func isUserSwitchingAwaitingScreen() -> Bool {
        if case .userSwitchingAwaitingScreen = state.value {
            return true
        }
        return false
    }

    // MARK: - State Transition Methods

    /**
     * Transitions to Normal state after initial screen event is sent.
     * This indicates normal operation where user is fully identified and tracking.
     */
    func markNormal() {
        state.value = .normal
        logger.info("📝 User session state: Normal")
    }

    /**
     * Transitions to BackgroundToInitialScreen state when the app returns from background.
     * This state ensures proper session handling with a fake reload screen event.
     */
    func markUserBackFromBackground() {
        state.value = .backgroundToInitialScreen
        logger.info("📝 User session state: BackgroundToInitialScreen")
    }

    /**
     * Transitions to UserSwitching state when a user switch is detected.
     * This state ensures proper session handling and initial screen event for the new user.
     */
    func markUserSwitch() {
        state.value = .userSwitching
        logger.info("📝 User session state: UserSwitching")
    }

    /**
     * Transitions to AwaitingInitialScreen state after user identification.
     * If currently in UserSwitching state, transitions to UserSwitchingAwaitingScreen
     * instead to preserve the user switch context.
     */
    func markAwaitingInitialScreen() {
        let currentState = state.value
        let newState: UserSessionState

        if case .userSwitching = currentState {
            newState = .userSwitchingAwaitingScreen
        } else {
            newState = .awaitingInitialScreen
        }

        state.value = newState
        logger.info("📝 User session state: %@", String(describing: newState))
    }

    // MARK: - High-Level Operations

    /**
     * Determines if this is a post-identification scenario requiring a screen event.
     * Returns true if we're in a state that needs an initial screen or if this is an identify event.
     *
     * @param eventName The name of the event being processed
     * @return true if screen event should be requested after this event
     */
    func isPostIdentificationContext(_ eventName: String) -> Bool {
        return (eventName == Constants.Event.identifyEvent || needsInitialScreen())
    }

    /**
     * Determines if an initial screen event should be requested based on current state and conditions.
     *
     * @param eventsQueueEmpty Whether the events queue is empty
     * @param hasCurrentScreen Whether there's a current screen available
     * @return true if initial screen event should be requested
     */
    func shouldRequestInitialScreenEvent(
        _ eventsQueueEmpty: Bool,
        _ hasCurrentScreen: Bool
    ) -> Bool {
        return eventsQueueEmpty && hasCurrentScreen
    }

    /**
     * Handles the post-identification screen event logic and returns the configuration
     * for how to publish the screen event.
     *
     * @param currentStartSession The current value of startSession flag
     * @return PostIdentificationScreenConfig with startSession and fakeReload settings
     */
    func getPostIdentificationScreenConfig(
        currentStartSession: Bool
    ) -> PostIdentificationScreenConfig {
        let isUserSwitch = isUserSwitching() || isUserSwitchingAwaitingScreen()

        return PostIdentificationScreenConfig(
            // For user switch, ensure startSession is true
            startSession: isUserSwitch ? true : currentStartSession,
            // User switch = no fake reload (true screen change)
            // Normal post-identify = fake reload
            isFakeReload: !isUserSwitch
        )
    }

    /**
     * Gets the post-identification start session configuration.
     *
     * @param currentStartSession The current value of startSession flag
     * @return true if this should be marked as a session start
     */
    func getPostIdentificationStartSessionConfig(
        currentStartSession: Bool
    ) -> Bool {
        let isUserSwitch = isUserSwitching() || isUserSwitchingAwaitingScreen()
        return isUserSwitch ? true : currentStartSession
    }

    /**
     * Gets the post-identification fake reload configuration.
     *
     * @return true if this is a fake reload (post-identify), false for real screen change
     */
    func getPostIdentificationFakeReloadConfig() -> Bool {
        let isUserSwitch = isUserSwitching() || isUserSwitchingAwaitingScreen()
        return !isUserSwitch
    }
}

// MARK: - UserSessionStateManaging Conformance

extension UserSessionStateManager: UserSessionStateManaging {}

// MARK: - PostIdentificationScreenConfig

extension UserSessionStateManager {
    /**
     * Configuration for how to handle post-identification screen events.
     *
     * @param startSession Whether this should be marked as a session start
     * @param isFakeReload Whether this is a fake reload (post-identify) or real screen change
     */
    struct PostIdentificationScreenConfig {
        let startSession: Bool
        let isFakeReload: Bool
    }
}
