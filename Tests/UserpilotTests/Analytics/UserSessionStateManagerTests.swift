//
//  UserSessionStateManagerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest

@testable import Userpilot

// swiftlint:disable all
class UserSessionStateManagerTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var logger: MockLogger!
    private var stateManager: UserSessionStateManaging!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        logger = MockLogger()
        config.logger = logger
        userpilot = MockUserpilot(config: config)

        stateManager = UserSessionStateManager(container: userpilot.container)
    }

    override func tearDown() {
        userpilot = nil
        stateManager = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_IsAwaitingInitialScreen() {
        // When: StateManager is initialized
        // Then: Initial state should be AwaitingInitialScreen
        XCTAssertTrue(stateManager.isAwaitingInitialScreen())
        XCTAssertFalse(stateManager.isNormal())
        XCTAssertFalse(stateManager.isUserSwitching())
        XCTAssertTrue(stateManager.needsInitialScreen())
    }

    // MARK: - State Transition Tests

    func testMarkNormal_TransitionsCorrectly() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()

        // When: Mark as normal
        stateManager.markNormal()

        // Then: State should be Normal
        XCTAssertTrue(stateManager.isNormal())
        XCTAssertFalse(stateManager.isAwaitingInitialScreen())
        XCTAssertFalse(stateManager.isUserSwitching())
        XCTAssertFalse(stateManager.needsInitialScreen())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("Normal") ?? false)
    }

    func testMarkUserSwitch_TransitionsCorrectly() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()

        // When: Mark as user switching
        stateManager.markUserSwitch()

        // Then: State should be UserSwitching
        XCTAssertTrue(stateManager.isUserSwitching())
        XCTAssertFalse(stateManager.isNormal())
        XCTAssertTrue(stateManager.needsInitialScreen())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("UserSwitching") ?? false)
    }

    func testMarkUserBackFromBackground_TransitionsCorrectly() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()

        // When: Mark as back from background
        stateManager.markUserBackFromBackground()

        // Then: State should be BackgroundToInitialScreen
        let currentState = stateManager.getCurrentState()
        if case .backgroundToInitialScreen = currentState {
            // Success
        } else {
            XCTFail("Expected BackgroundToInitialScreen state")
        }

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("BackgroundToInitialScreen") ?? false)
    }

    func testMarkAwaitingInitialScreen_FromNormalState() {
        // Given: State is Normal
        stateManager.markNormal()
        logger.loggedInfos.removeAll()  // Clear logs

        // When: Mark awaiting initial screen
        stateManager.markAwaitingInitialScreen()

        // Then: State should be AwaitingInitialScreen
        XCTAssertTrue(stateManager.isAwaitingInitialScreen())
        XCTAssertTrue(stateManager.needsInitialScreen())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("AwaitingInitialScreen") ?? false)
    }

    func testMarkAwaitingInitialScreen_FromUserSwitchingState() {
        // Given: State is UserSwitching
        stateManager.markUserSwitch()
        logger.loggedInfos.removeAll()  // Clear logs

        // When: Mark awaiting initial screen
        stateManager.markAwaitingInitialScreen()

        // Then: State should be UserSwitchingAwaitingScreen
        XCTAssertTrue(stateManager.isUserSwitchingAwaitingScreen())
        XCTAssertTrue(stateManager.isUserSwitching())
        XCTAssertTrue(stateManager.needsInitialScreen())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("UserSwitchingAwaitingScreen") ?? false)
    }

    // MARK: - State Check Tests

    func testUserSessionState_IsUserSwitching() {
        // Test UserSwitching state
        stateManager.markUserSwitch()
        XCTAssertTrue(stateManager.isUserSwitching())

        // Test UserSwitchingAwaitingScreen state
        stateManager.markUserSwitch()
        stateManager.markAwaitingInitialScreen()
        XCTAssertTrue(stateManager.isUserSwitching())
        XCTAssertTrue(stateManager.isUserSwitchingAwaitingScreen())

        // Test other states are not user switching
        stateManager.markNormal()
        XCTAssertFalse(stateManager.isUserSwitching())
    }

    func testUserSessionState_NeedsInitialScreen() {
        // Test AwaitingInitialScreen
        // (Already in this state from initialization)
        XCTAssertTrue(stateManager.needsInitialScreen())

        // Test UserSwitching
        stateManager.markUserSwitch()
        XCTAssertTrue(stateManager.needsInitialScreen())

        // Test UserSwitchingAwaitingScreen
        stateManager.markAwaitingInitialScreen()
        XCTAssertTrue(stateManager.needsInitialScreen())

        // Test Normal state does not need initial screen
        stateManager.markNormal()
        XCTAssertFalse(stateManager.needsInitialScreen())
    }

    // MARK: - High-Level Operations Tests

    func testIsPostIdentificationContext_WithIdentifyEvent() {
        // Given: Any state
        stateManager.markNormal()

        // When: Event is identify
        let result = stateManager.isPostIdentificationContext(
            Constants.Event.identifyEvent
        )

        // Then: Should return true
        XCTAssertTrue(result)
    }

    func testIsPostIdentificationContext_WithNeedsInitialScreen() {
        // Given: State needs initial screen
        // (Initial state is AwaitingInitialScreen)

        // When: Event is not identify
        let result = stateManager.isPostIdentificationContext(
            Constants.Event.screenEvent
        )

        // Then: Should return true
        XCTAssertTrue(result)
    }

    func testIsPostIdentificationContext_WithNormalStateAndNonIdentifyEvent() {
        // Given: Normal state (doesn't need initial screen)
        stateManager.markNormal()

        // When: Event is not identify
        let result = stateManager.isPostIdentificationContext(
            Constants.Event.trackEvent
        )

        // Then: Should return false
        XCTAssertFalse(result)
    }

    func testShouldRequestInitialScreenEvent_BothConditionsTrue() {
        let result = stateManager.shouldRequestInitialScreenEvent(
            true,
            true
        )
        XCTAssertTrue(result)
    }

    func testShouldRequestInitialScreenEvent_QueueNotEmpty() {
        let result = stateManager.shouldRequestInitialScreenEvent(
            false,
            true
        )
        XCTAssertFalse(result)
    }

    func testShouldRequestInitialScreenEvent_NoCurrentScreen() {
        let result = stateManager.shouldRequestInitialScreenEvent(
            true,
            false
        )
        XCTAssertFalse(result)
    }

    // MARK: - Post-Identification Config Tests

    func testGetPostIdentificationScreenConfig_NormalState() {
        // Given: Normal state (not user switching)
        stateManager.markNormal()

        // When: Get config with startSession = false
        let config = stateManager.getPostIdentificationScreenConfig(
            currentStartSession: false
        )

        // Then: Should keep startSession as is and set fake reload
        XCTAssertFalse(config.startSession)
        XCTAssertTrue(config.isFakeReload)
    }

    func testGetPostIdentificationScreenConfig_UserSwitchingState() {
        // Given: UserSwitching state
        stateManager.markUserSwitch()

        // When: Get config with startSession = false
        let config = stateManager.getPostIdentificationScreenConfig(
            currentStartSession: false
        )

        // Then: Should force startSession to true and no fake reload
        XCTAssertTrue(config.startSession)
        XCTAssertFalse(config.isFakeReload)
    }

    func testGetPostIdentificationScreenConfig_UserSwitchingAwaitingScreenState() {
        // Given: UserSwitchingAwaitingScreen state
        stateManager.markUserSwitch()
        stateManager.markAwaitingInitialScreen()

        // When: Get config with startSession = false
        let config = stateManager.getPostIdentificationScreenConfig(
            currentStartSession: false
        )

        // Then: Should force startSession to true and no fake reload
        XCTAssertTrue(config.startSession)
        XCTAssertFalse(config.isFakeReload)
    }

    func testGetPostIdentificationStartSessionConfig_NormalState() {
        // Given: Normal state
        stateManager.markNormal()

        // When: Get config with currentStartSession = false
        let result = stateManager.getPostIdentificationStartSessionConfig(
            currentStartSession: false
        )

        // Then: Should keep currentStartSession value
        XCTAssertFalse(result)
    }

    func testGetPostIdentificationStartSessionConfig_UserSwitching() {
        // Given: UserSwitching state
        stateManager.markUserSwitch()

        // When: Get config with currentStartSession = false
        let result = stateManager.getPostIdentificationStartSessionConfig(
            currentStartSession: false
        )

        // Then: Should force to true
        XCTAssertTrue(result)
    }

    func testGetPostIdentificationFakeReloadConfig_NormalState() {
        // Given: Normal state
        stateManager.markNormal()

        // When: Get fake reload config
        let result = stateManager.getPostIdentificationFakeReloadConfig()

        // Then: Should be true (is fake reload)
        XCTAssertTrue(result)
    }

    func testGetPostIdentificationFakeReloadConfig_UserSwitching() {
        // Given: UserSwitching state
        stateManager.markUserSwitch()

        // When: Get fake reload config
        let result = stateManager.getPostIdentificationFakeReloadConfig()

        // Then: Should be false (not fake reload)
        XCTAssertFalse(result)
    }

    // MARK: - Complete Workflow Tests

    func testCompleteWorkflow_FirstTimeIdentification() {
        // 1. Initial state: AwaitingInitialScreen
        XCTAssertTrue(stateManager.isAwaitingInitialScreen())
        XCTAssertTrue(stateManager.needsInitialScreen())

        // 2. User gets identified -> still awaiting initial screen
        XCTAssertTrue(
            stateManager.isPostIdentificationContext(
                Constants.Event.identifyEvent
            ))

        // 3. Initial screen sent -> transition to Normal
        stateManager.markNormal()
        XCTAssertTrue(stateManager.isNormal())
        XCTAssertFalse(stateManager.needsInitialScreen())
    }

    func testCompleteWorkflow_UserSwitch() {
        // 1. Start in Normal state
        stateManager.markNormal()
        XCTAssertTrue(stateManager.isNormal())

        // 2. User switch detected
        stateManager.markUserSwitch()
        XCTAssertTrue(stateManager.isUserSwitching())
        XCTAssertTrue(stateManager.needsInitialScreen())

        // 3. New user identified -> UserSwitchingAwaitingScreen
        stateManager.markAwaitingInitialScreen()
        XCTAssertTrue(stateManager.isUserSwitchingAwaitingScreen())
        XCTAssertTrue(stateManager.isUserSwitching())

        // 4. Verify config for user switch
        let config = stateManager.getPostIdentificationScreenConfig(
            currentStartSession: false
        )
        XCTAssertTrue(config.startSession)
        XCTAssertFalse(config.isFakeReload)

        // 5. Initial screen sent -> back to Normal
        stateManager.markNormal()
        XCTAssertTrue(stateManager.isNormal())
        XCTAssertFalse(stateManager.isUserSwitching())
    }

    func testCompleteWorkflow_BackgroundToForeground() {
        // 1. Start in Normal state
        stateManager.markNormal()

        // 2. App goes to background and returns
        stateManager.markUserBackFromBackground()

        // 3. Verify state
        let currentState = stateManager.getCurrentState()
        if case .backgroundToInitialScreen = currentState {
            // Success
        } else {
            XCTFail("Expected BackgroundToInitialScreen state")
        }

        // 4. Screen event sent -> back to Normal
        stateManager.markNormal()
        XCTAssertTrue(stateManager.isNormal())
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_ConcurrentStateTransitions() {
        logger.loggedInfos.removeAll()
        let expectation = self.expectation(description: "All transitions complete")
        let group = DispatchGroup()
        let iterations = 100

        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                switch index % 4 {
                case 0:
                    self.stateManager.markNormal()
                case 1:
                    self.stateManager.markUserSwitch()
                case 2:
                    self.stateManager.markAwaitingInitialScreen()
                case 3:
                    self.stateManager.markUserBackFromBackground()
                default:
                    break
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        // Should have logged all transitions without crashes
        XCTAssertEqual(logger.loggedInfos.count, iterations)
    }

    func testThreadSafety_ConcurrentReadsAndWrites() {
        logger.loggedInfos.removeAll()
        let expectation = self.expectation(description: "All operations complete")
        let group = DispatchGroup()
        let iterations = 200

        // Readers
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                _ = self.stateManager.isUserSwitching()
                _ = self.stateManager.needsInitialScreen()
                _ = self.stateManager.getCurrentState()
                group.leave()
            }
        }

        // Writers
        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                if index % 2 == 0 {
                    self.stateManager.markNormal()
                } else {
                    self.stateManager.markUserSwitch()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        // Should complete without crashes
        XCTAssertTrue(true)
    }
}
// swiftlint:enable all
