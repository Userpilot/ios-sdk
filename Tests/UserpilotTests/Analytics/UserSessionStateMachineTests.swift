//
//  UserSessionStateMachineTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies session transitions and the screen flags consumed by analytics delivery.
//

import XCTest
@testable import Userpilot

final class UserSessionStateMachineTests: XCTestCase {
    private var sessions: UserSessionStateManaging!
    private var logger: MockLogger!

    override func setUp() {
        super.setUp()
        logger = MockLogger()
        let config = Userpilot.Config(token: "test-token")
        config.logger = logger
        let container = DIContainer()
        container.register(Userpilot.Config.self, value: config)
        sessions = UserSessionStateMachine(container: container)
    }

    override func tearDown() {
        sessions = nil
        logger = nil
        super.tearDown()
    }

    func testInitialStateNeedsAScreenWithoutSwitchingUsers() {
        XCTAssertEqual(sessions.getCurrentState(), .awaitingInitialScreen)
        XCTAssertFalse(sessions.isUserSwitching())
        XCTAssertTrue(sessions.isPostIdentificationContext(Constants.Event.trackEvent))
    }

    func testNormalIdentificationSettlesAfterScreenAcknowledgement() {
        sessions.markAwaitingInitialScreen()
        XCTAssertEqual(sessions.getCurrentState(), .awaitingInitialScreen)

        sessions.markNormal()
        XCTAssertEqual(sessions.getCurrentState(), .normal)
        XCTAssertFalse(sessions.isPostIdentificationContext(Constants.Event.trackEvent))
    }

    func testSwitchContextSurvivesIdentifyUntilScreenAcknowledgement() {
        sessions.markUserSwitch()
        XCTAssertEqual(sessions.getCurrentState(), .userSwitching)
        XCTAssertTrue(sessions.isUserSwitching())

        sessions.markAwaitingInitialScreen()
        XCTAssertEqual(sessions.getCurrentState(), .userSwitchingAwaitingScreen)
        XCTAssertTrue(sessions.isUserSwitching())

        sessions.markNormal()
        XCTAssertFalse(sessions.isUserSwitching())
        XCTAssertEqual(sessions.getCurrentState(), .normal)
    }

    func testRepeatedIdentifyPreservesPendingSessionStart() {
        sessions.markUserSwitch()
        sessions.markAwaitingInitialScreen()
        sessions.markAwaitingInitialScreen()

        XCTAssertEqual(sessions.getCurrentState(), .userSwitchingAwaitingScreen)
        XCTAssertTrue(sessions.isUserSwitching())
        XCTAssertTrue(sessions.getPostIdentificationScreenConfig(currentStartSession: false).startSession)
    }

    func testBackgroundRefreshIsSeparateFromInitialScreenContext() {
        sessions.markNormal()
        sessions.markUserBackFromBackground()

        XCTAssertEqual(sessions.getCurrentState(), .backgroundToInitialScreen)
        XCTAssertFalse(sessions.isUserSwitching())
        XCTAssertFalse(sessions.isPostIdentificationContext(Constants.Event.trackEvent))
        XCTAssertTrue(sessions.isPostIdentificationContext(Constants.Event.identifyEvent))
    }

    func testIdentifyRestartsInitialScreenContextAfterBackground() {
        sessions.markUserBackFromBackground()
        sessions.markAwaitingInitialScreen()

        XCTAssertEqual(sessions.getCurrentState(), .awaitingInitialScreen)
        XCTAssertTrue(sessions.isPostIdentificationContext(Constants.Event.trackEvent))
    }

    func testIdentifyAcknowledgementQualifiesInEveryState() {
        for state in allStates {
            moveToState(state)
            XCTAssertTrue(sessions.isPostIdentificationContext(Constants.Event.identifyEvent), "\(state)")
        }
    }

    func testOtherAcknowledgementsOnlyQualifyWhileAnInitialScreenIsDue() {
        let initialStates: [UserSessionState] = [.awaitingInitialScreen, .userSwitching, .userSwitchingAwaitingScreen]
        for state in allStates {
            moveToState(state)
            XCTAssertEqual(
                sessions.isPostIdentificationContext(Constants.Event.trackEvent),
                initialStates.contains(state),
                "\(state)"
            )
        }
    }

    func testInitialScreenRequiresEmptyQueueAndKnownScreen() {
        XCTAssertTrue(sessions.shouldRequestInitialScreenEvent(true, true))
        XCTAssertFalse(sessions.shouldRequestInitialScreenEvent(false, true))
        XCTAssertFalse(sessions.shouldRequestInitialScreenEvent(true, false))
        XCTAssertFalse(sessions.shouldRequestInitialScreenEvent(false, false))
    }

    func testScreenFlagsPreserveStartSessionExceptDuringUserSwitch() {
        for state in allStates {
            moveToState(state)
            let switching = state == .userSwitching || state == .userSwitchingAwaitingScreen
            for startSession in [false, true] {
                let config = sessions.getPostIdentificationScreenConfig(currentStartSession: startSession)
                XCTAssertEqual(config.startSession, switching || startSession, "\(state)")
                XCTAssertEqual(config.isFakeReload, !switching, "\(state)")
                XCTAssertEqual(sessions.getCurrentState(), state, "Configuration reads must not consume state")
            }
        }
    }

    func testTransitionDiagnosticNamesRemainUnchanged() {
        sessions.markNormal()
        sessions.markUserBackFromBackground()
        sessions.markUserSwitch()
        sessions.markAwaitingInitialScreen()
        sessions.markAwaitingInitialScreen()

        sessions.markNormal()
        sessions.markAwaitingInitialScreen()

        XCTAssertEqual(logger.loggedInfos, [
            "📝 User session state: Normal",
            "📝 User session state: BackgroundToInitialScreen",
            "📝 User session state: UserSwitching",
            "📝 User session state: UserSwitchingAwaitingScreen",
            "📝 User session state: UserSwitchingAwaitingScreen",
            "📝 User session state: Normal",
            "📝 User session state: AwaitingInitialScreen"
        ])
    }

    private var allStates: [UserSessionState] {
        [.normal, .userSwitching, .awaitingInitialScreen, .userSwitchingAwaitingScreen, .backgroundToInitialScreen]
    }

    private func moveToState(_ state: UserSessionState) {
        sessions.markNormal()
        switch state {
        case .normal:
            break
        case .userSwitching:
            sessions.markUserSwitch()
        case .awaitingInitialScreen:
            sessions.markAwaitingInitialScreen()
        case .userSwitchingAwaitingScreen:
            sessions.markUserSwitch()
            sessions.markAwaitingInitialScreen()
        case .backgroundToInitialScreen:
            sessions.markUserBackFromBackground()
        }
    }
}
