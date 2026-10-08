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

        sessions.acknowledgeScreen()
        XCTAssertTrue(sessions.isStartSession)
        XCTAssertEqual(sessions.getCurrentState(), .normal)
        XCTAssertFalse(sessions.isPostIdentificationContext(Constants.Event.trackEvent))
    }

    func testSwitchContextSurvivesIdentifyUntilScreenAcknowledgement() {
        sessions.beginSession()
        XCTAssertEqual(sessions.getCurrentState(), .userSwitching)
        XCTAssertTrue(sessions.isUserSwitching())

        sessions.markAwaitingInitialScreen()
        XCTAssertEqual(sessions.getCurrentState(), .userSwitchingAwaitingScreen)
        XCTAssertTrue(sessions.isUserSwitching())

        sessions.acknowledgeScreen()
        XCTAssertTrue(sessions.isStartSession)
        XCTAssertFalse(sessions.isUserSwitching())
        XCTAssertEqual(sessions.getCurrentState(), .normal)
    }

    func testRepeatedIdentifyPreservesPendingSessionStart() {
        sessions.beginSession()
        sessions.markAwaitingInitialScreen()
        sessions.markAwaitingInitialScreen()

        XCTAssertEqual(sessions.getCurrentState(), .userSwitchingAwaitingScreen)
        XCTAssertTrue(sessions.isUserSwitching())
        XCTAssertTrue(sessions.getPostIdentificationScreenConfig().startSession)
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
                sessions.resumeSession(isExpired: startSession)
                let config = sessions.getPostIdentificationScreenConfig()
                XCTAssertEqual(config.startSession, switching || startSession, "\(state)")
                XCTAssertEqual(config.isFakeReload, !switching, "\(state)")
                XCTAssertEqual(sessions.getCurrentState(), state, "Configuration reads must not consume state")
                XCTAssertEqual(sessions.isStartSession, startSession, "Configuration reads must not change the flag")
            }
        }
    }

    func testBeginSessionRestoresStartAfterNavigation() {
        sessions.acknowledgeScreen()
        sessions.markScreenChanged()
        XCTAssertFalse(sessions.isStartSession)

        sessions.beginSession()

        XCTAssertTrue(sessions.isStartSession)
        let config = sessions.getPostIdentificationScreenConfig()
        XCTAssertTrue(config.startSession)
        XCTAssertFalse(config.isFakeReload)
    }

    func testRepeatedSameUserIdentifyPreservesBothStartSessionValues() {
        for startSession in [false, true] {
            sessions.markNormal()
            sessions.resumeSession(isExpired: startSession)

            sessions.markAwaitingInitialScreen()
            sessions.markAwaitingInitialScreen()

            XCTAssertEqual(sessions.isStartSession, startSession)
            let config = sessions.getPostIdentificationScreenConfig()
            XCTAssertEqual(config.startSession, startSession)
            XCTAssertTrue(config.isFakeReload)
        }
    }

    func testBackgroundRefreshAdmissionPreservesStartThroughScreenAcknowledgement() {
        for expired in [false, true] {
            sessions.markUserBackFromBackground()
            sessions.resumeSession(isExpired: expired)
            sessions.markNormal()

            let config = sessions.prepareScreen(isFakeReload: false)
            XCTAssertEqual(config.startSession, expired)
            XCTAssertFalse(config.isFakeReload)
            XCTAssertEqual(sessions.isStartSession, expired)

            sessions.acknowledgeScreen()
            XCTAssertEqual(sessions.isStartSession, expired)
            XCTAssertEqual(sessions.getCurrentState(), .normal)
        }
    }

    func testNavigationEndsSessionStartWithoutPendingIdentityBoundary() {
        sessions.markNormal()
        sessions.markScreenChanged()

        XCTAssertFalse(sessions.prepareScreen(isFakeReload: false).startSession)
        XCTAssertFalse(sessions.isStartSession)
    }

    func testPendingIdentityBoundarySurvivesNavigationUntilScreenPreparation() {
        sessions.beginSession()
        sessions.markAwaitingInitialScreen()
        sessions.markScreenChanged()
        XCTAssertFalse(sessions.isStartSession)

        let config = sessions.prepareScreen(isFakeReload: false)

        XCTAssertTrue(config.startSession)
        XCTAssertTrue(sessions.isStartSession)
        XCTAssertEqual(sessions.getCurrentState(), .userSwitchingAwaitingScreen)
    }

    func testPrepareScreenPreservesQueuedReloadIntentAndStoresResolvedStart() {
        for state in allStates {
            moveToState(state)
            let switching = state.isUserSwitching()
            for startSession in [false, true] {
                for isFakeReload in [false, true] {
                    sessions.resumeSession(isExpired: startSession)

                    let config = sessions.prepareScreen(isFakeReload: isFakeReload)

                    XCTAssertEqual(config.startSession, switching || startSession, "\(state)")
                    XCTAssertEqual(config.isFakeReload, isFakeReload, "Queued screen intent must be retained")
                    XCTAssertEqual(sessions.isStartSession, config.startSession)
                    XCTAssertEqual(sessions.getCurrentState(), state, "Preparation must not consume session context")
                }
            }
        }
    }

    func testResetSessionStartPreservesBackgroundContext() {
        sessions.acknowledgeScreen()
        sessions.markScreenChanged()
        XCTAssertFalse(sessions.isStartSession)
        sessions.markUserBackFromBackground()

        sessions.resetSessionStart()

        XCTAssertTrue(sessions.isStartSession)
        XCTAssertEqual(sessions.getCurrentState(), .backgroundToInitialScreen)
        XCTAssertTrue(sessions.getPostIdentificationScreenConfig().isFakeReload)
    }

    func testTransitionDiagnosticNamesRemainUnchanged() {
        sessions.markNormal()
        sessions.markUserBackFromBackground()
        sessions.beginSession()
        sessions.markAwaitingInitialScreen()
        sessions.markAwaitingInitialScreen()

        sessions.acknowledgeScreen()
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
            sessions.beginSession()
        case .awaitingInitialScreen:
            sessions.markAwaitingInitialScreen()
        case .userSwitchingAwaitingScreen:
            sessions.beginSession()
            sessions.markAwaitingInitialScreen()
        case .backgroundToInitialScreen:
            sessions.markUserBackFromBackground()
        }
    }
}
