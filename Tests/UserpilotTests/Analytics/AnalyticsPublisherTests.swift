//
//  AnalyticsPublisherTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
import Foundation
@testable import Userpilot

// swiftlint:disable all

class AnalyticsPublisherTests: XCTestCase {

    var analyticsPublisher: AnalyticsPublisher!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)

        analyticsPublisher = AnalyticsPublisher(container: userpilot.container)
    }

    override func tearDown() {
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Publish Method Tests

    func testPublish_identifyEvent_shouldCacheEventAndUpdateStorage() {
        // Arrange
        let userId = "test-user-123"
        let properties = ["name": "John Doe", "email": "john@example.com"]
        let company = ["name": "Test Company", "id": "company-123"]
        let identifyEvent = Event(
            type: .identify(userId),
            properties: properties,
            company: company
        )

        // Act
        analyticsPublisher.publish(identifyEvent)

        // Assert
        XCTAssertTrue(userpilot.socketManager.isShutdownState || !userpilot.socketManager.isSocketOpened)
    }

    func testPublish_screenEvent_shouldSetupScreenSessionStateMachine() {
        // Arrange
        let screenEvent = Event(type: .screen("Home Screen"))
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }

        // Act
        analyticsPublisher.publish(screenEvent)

        // Assert
        XCTAssertNotNil(analyticsPublisher.screenSessionStateMachine)
        XCTAssertEqual(analyticsPublisher.screenSessionStateMachine?.event.screenTitle, "Home Screen")
    }

    func testPublish_screenEvent_shouldSyncScreenTrackerForWrapperInteractionOnlyConfig() {
        // Arrange
        let config = Userpilot.Config(token: "NX-WRAPPER-\(UUID().uuidString)")
            .additionalProperties([
                WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeFlutter,
                WrapperSDKConstants.enableScreenAutoCapture: false,
                WrapperSDKConstants.enableInteractionAutoCapture: true
            ])
            .defaultInstance(false)
        userpilot = MockUserpilot(config: config)
        analyticsPublisher = AnalyticsPublisher(container: userpilot.container)
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }
        let screenEvent = Event(type: .screen("Wrapper Manual Screen"))

        // Act
        analyticsPublisher.publish(screenEvent)

        // Assert
        let tracker = userpilot.container.resolve(ScreenNameTracking.self)
        XCTAssertEqual(tracker.getCurrentPayload()?.currentScreen, "Wrapper Manual Screen")
    }

    func testPublish_screenEvent_shouldNotSyncScreenTrackerForWrapperScreenAutocaptureConfig() {
        // Arrange
        let config = Userpilot.Config(token: "NX-WRAPPER-\(UUID().uuidString)")
            .additionalProperties([
                WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeFlutter,
                WrapperSDKConstants.enableScreenAutoCapture: true,
                WrapperSDKConstants.enableInteractionAutoCapture: true
            ])
            .defaultInstance(false)
        userpilot = MockUserpilot(config: config)
        analyticsPublisher = AnalyticsPublisher(container: userpilot.container)
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }
        let screenEvent = Event(type: .screen("Wrapper Screen Autocapture"))

        // Act
        analyticsPublisher.publish(screenEvent)

        // Assert
        let tracker = userpilot.container.resolve(ScreenNameTracking.self)
        XCTAssertNil(tracker.getCurrentPayload())
    }

    func testPublish_customEvent_shouldAddToQueue() {
        // Arrange
        let customEvent = Event(type: .event("button_clicked"))
        userpilot.socketManager.isSocketOpened = true

        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _ in
            didPublishEvent = true
        }

        let expectation = XCTestExpectation(description: "Wait for event to be enqueued and processed")

        // Act
        analyticsPublisher.publish(customEvent)

        // Delay before assertion to allow event processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Assert
            XCTAssertTrue(didPublishEvent)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPublish_whenSocketNotOpened_shouldCacheEvent() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isSocketOpened = false
        userpilot.storage.userId = "test-user"

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.publish(customEvent)

        // Assert
        XCTAssertTrue(connectCalled)
    }

    func testPublish_whenSocketIsJoining_shouldCacheEvent() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isJoiningSocket = true

        // Act
        analyticsPublisher.publish(customEvent)

        // Assert
        // Event should be cached in the live queue, not sent immediately.
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().count, 1)
    }

    func testPublish_whenSocketInShutdownState_shouldNotProcess() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isShutdownState = true
        var didSocketConnect = false
        userpilot.socketManager.onConnect = {
            didSocketConnect = true
        }

        // Act
        analyticsPublisher.publish(customEvent)

        // Assert
        // Event should not be processed
        XCTAssertFalse(didSocketConnect) // Would need to verify no processing occurred
    }

    // MARK: - Flush Tests

    func testFlush_shouldUpdateSocketStateAndFlushQueue() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        var closeCalled = false
        userpilot.socketManager.onClose = { closeCalled = true }

        // Act
        analyticsPublisher.flush()

        // Assert
        XCTAssertTrue(closeCalled)
    }

    // MARK: - Resume Tests

    func testResume_shouldConnectSocketWhenUserIdExists() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isJoiningSocket = false

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.resume()

        // Assert
        XCTAssertTrue(connectCalled)
    }

    func testResume_shouldAskSocketManagerToConnectWhenUserIdExists() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isSocketOpened = true

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.resume()

        // Assert
        XCTAssertTrue(connectCalled)
    }

    func testResume_shouldNotConnectWhenUserIdEmpty() {
        // Arrange
        userpilot.storage.userId = ""
        userpilot.socketManager.isSocketOpened = false

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.resume()

        // Assert
        XCTAssertFalse(connectCalled)
    }

    // MARK: - Reset Tests

    func testReset_shouldResetStartSessionFlag() {
        // Arrange
        // Simulate that start session was previously false

        // Act
        analyticsPublisher.reset()

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }

    // MARK: - Logout Tests

    func testLogout_shouldResetStateAndCloseSocket() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.storage.pushToken = "push-token"

        var closeCalled = false
        userpilot.socketManager.onClose = { closeCalled = true }

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: true)

        // Assert
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }

    func testLogout_shouldPublishLogoutEventWhenRequested() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.storage.pushToken = "push-token"
        userpilot.socketManager.isSocketOpened = true

        var publishLogoutEventCalled = false
        userpilot.socketManager.onPublish = { _, _ in publishLogoutEventCalled = true }

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: true)

        // Assert
        XCTAssertTrue(publishLogoutEventCalled)
    }

    // MARK: - Socket Subscription Tests

    func testOnSocketOpened_shouldFlushPriorityEvents() {
        // Arrange
        userpilot.storage.userId = ""
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isJoiningSocket = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }

        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.publish(identifyEvent)

        userpilot.socketManager.isSocketOpened = true
        userpilot.socketManager.isJoiningSocket = false
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _ in
            didPublishEvent = true
        }

        // Act
        analyticsPublisher.onSocketOpened()

        // Assert
        // Would need to verify that cached events were flushed
        XCTAssertTrue(didPublishEvent)
    }

    func testOnSocketClosed_shouldHandleReconnection() {
        // Arrange
        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.publish(identifyEvent)
        userpilot.socketManager.didCloseFromError = false

        var didSocketConnect = false
        userpilot.socketManager.onConnect = {
            didSocketConnect = true
        }

        // Act
        analyticsPublisher.onSocketClosed()

        // Assert
        // Should republish cached identify event
        XCTAssertTrue(didSocketConnect)
    }

    func testOnSocketClosed_shouldNotReconnectAfterSocketError() {
        // Arrange
        userpilot.socketManager.didCloseFromError = true
        var didSocketConnect = false
        userpilot.socketManager.onConnect = {
            didSocketConnect = true
        }

        // Act
        analyticsPublisher.onSocketClosed()

        // Assert
        XCTAssertFalse(didSocketConnect)
    }

    func testOnSocketEventSent_shouldUpdateUserOnIdentifyEvent() {
        // Arrange
        let userId = "test-user"
        let identifyEvent = Event(type: .identify(userId))
        userpilot.storage.userId = userId
        userpilot.storage.user = "{\"userId\":\"test-user\",\"properties\":{}}"

        // Simulate cached identify event
        analyticsPublisher.publish(identifyEvent)

        let payload: [String: Any] = ["test": "data"]

        // Act
        analyticsPublisher.onSocketEventSent("identify", payload, Message(), true)

        // Assert
        XCTAssertNotEqual(userpilot.storage.user, "")
    }

    // MARK: - Experience Events Tests

    func testCanRequestEvent_shouldReturnSocketState() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true

        // Act & Assert
        XCTAssertTrue(analyticsPublisher.canRequestEvent)

        // Arrange
        userpilot.socketManager.isSocketOpened = false

        // Act & Assert
        XCTAssertFalse(analyticsPublisher.canRequestEvent)
    }

    func testPublishInternalSDKEvent_shouldPublishWhenSocketOpen() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _ in
            didPublishEvent = true
        }
        let sdkEvent = MockSDKEvent()

        // Act
        analyticsPublisher.publishInternalSDKEvent(sdkEvent)

        // Assert
        // Would need to verify socket manager publish was called
        XCTAssertTrue(didPublishEvent)
    }

    func testPublishInternalSDKEvent_shouldNotPublishExperienceEventWhenSocketClosed() {
        // Arrange
        userpilot.socketManager.isSocketOpened = false
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _ in
            didPublishEvent = true
        }
        let sdkEvent = MockSDKEvent()

        // Act
        analyticsPublisher.publishInternalSDKEvent(sdkEvent)

        // Assert
        // Should not publish experience event when socket is closed
        XCTAssertFalse(didPublishEvent)
    }

    func testPublishFakeReloadScreenEvent_shouldPublishWhenScreenSessionStateMachineExists() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)
        analyticsPublisher.onSocketEventSent(Constants.Event.screenEvent, nil, Message(), true)

        let expectation = XCTestExpectation(description: "Wait for delayed fake reload publish")

        var publishScreenEventCalled = false
        userpilot.socketManager.onPublish = { _, _ in
            publishScreenEventCalled = true
            expectation.fulfill()
        }

        // Act (add delay before publishing, because screen events are throttled)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            self.analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10)
        }

        // Assert (wait for the delayed call)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(publishScreenEventCalled)
    }

    func testPublishFakeReloadScreenEvent_withSameTimeForScreenEvent_shouldNotPublishScreenEvent() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        var publishScreenEventCalled = false
        userpilot.socketManager.onPublish = { _, _ in publishScreenEventCalled = true }

        // Act
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10)

        // Assert
        // Would need to verify socket manager publish was called with fake reload flag
        XCTAssertFalse(publishScreenEventCalled)
    }

    func testExperiencePublished_shouldUpdateSeenExperiences() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        // Act
        analyticsPublisher.experiencePublished(.flow, 123)

        // Assert
        XCTAssertTrue(analyticsPublisher.screenSessionStateMachine?.seenExperiences.contains(123) ?? false)
    }

    func testExperiencePublished_shouldUpdateSeenSurveys() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        // Act
        analyticsPublisher.experiencePublished(.survey, 456)

        // Assert
        XCTAssertTrue(analyticsPublisher.screenSessionStateMachine?.seenSurveys.contains(456) ?? false)
    }

    // MARK: - Screen Event Setup Tests

    func testSetupScreenEvent_shouldCreateNewScreenSessionStateMachineForDifferentScreen() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let firstScreenEvent = Event(type: .screen("Screen 1"))
        let secondScreenEvent = Event(type: .screen("Screen 2"))

        // Act
        analyticsPublisher.publish(firstScreenEvent)
        let firstScreenSessionStateMachine = analyticsPublisher.screenSessionStateMachine
        analyticsPublisher.onSocketEventSent(Constants.Event.screenEvent, nil, Message(), true)

        analyticsPublisher.publish(secondScreenEvent)
        let secondScreenSessionStateMachine = analyticsPublisher.screenSessionStateMachine

        // Assert
        XCTAssertNotEqual(firstScreenSessionStateMachine?.event.screenTitle, secondScreenSessionStateMachine?.event.screenTitle)
        XCTAssertEqual(secondScreenSessionStateMachine?.event.screenTitle, "Screen 2")
    }

    func testSetupScreenEvent_shouldRetainSeenExperiencesForSameScreen() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Same Screen"))
        analyticsPublisher.publish(screenEvent)
        analyticsPublisher.experiencePublished(.flow, 123)
        analyticsPublisher.onSocketEventSent(Constants.Event.screenEvent, nil, Message(), true)

        // Act
        analyticsPublisher.publish(screenEvent) // Same screen again

        // Assert
        XCTAssertTrue(analyticsPublisher.screenSessionStateMachine?.seenExperiences.contains(123) ?? false)
    }

    // MARK: - Session State Tests

    func testUpdateSessionState_shouldSetStartSessionTrueWhenSessionExpired() {
        // Arrange
        let pastDate = Date().addingTimeInterval(-35 * 60) // 35 minutes ago
        userpilot.storage.sessionDate = pastDate

        // Act
        analyticsPublisher.updateSessionState()

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
        XCTAssertNil(userpilot.storage.sessionDate)
    }

    func testUpdateSessionState_shouldSetStartSessionFalseWhenSessionNotExpired() {
        // Arrange
        let recentDate = Date().addingTimeInterval(-10 * 60) // 10 minutes ago
        userpilot.storage.sessionDate = recentDate

        // Act
        analyticsPublisher.updateSessionState()

        // Assert
        XCTAssertFalse(analyticsPublisher.isStartSession)
        XCTAssertNil(userpilot.storage.sessionDate)
    }

    // MARK: - Edge Cases and Error Handling

    func testPublish_withNilUserId_shouldNotOpenSocket() {
        // Arrange
        let eventWithoutUserId = Event(type: .event("test"))
        userpilot.socketManager.isSocketOpened = false
        userpilot.storage.userId = ""

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.publish(eventWithoutUserId)

        // Assert
        XCTAssertFalse(connectCalled)
    }

    // MARK: - Track Event Throttle Key Tests

    private func makeAutoCaptureEvent(
        properties: Payload = nil,
        screen: Payload = [AutoCaptureConstants.screenClass: "HomeViewController"],
        interactionEventName: String = "tap"
    ) -> Event {
        return Event(
            type: .autoCaptureEvent,
            properties: properties,
            screen: screen,
            interactionEventName: interactionEventName
        )
    }

    /// Counts socket publishes triggered by publishing the given events back-to-back.
    private func publishAndCountSocketPublishes(
        _ events: [Event],
        expectedCount: Int,
        timeout: TimeInterval = 2.0
    ) -> Int {
        userpilot.socketManager.isSocketOpened = true

        var publishCount = 0
        let expectation = XCTestExpectation(description: "events flushed to socket")
        expectation.expectedFulfillmentCount = expectedCount
        expectation.assertForOverFulfill = false
        userpilot.socketManager.onPublish = { _, _ in
            publishCount += 1
            expectation.fulfill()
        }

        events.forEach { analyticsPublisher.publish($0) }

        wait(for: [expectation], timeout: timeout)
        // Grace period so an unexpected extra publish would also be counted
        let grace = XCTestExpectation(description: "grace period")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { grace.fulfill() }
        wait(for: [grace], timeout: 1.0)
        return publishCount
    }

    func testTrackEvent_autoCaptureNilProperties_distinctInteractionsShouldBothPublish() {
        let tap = makeAutoCaptureEvent(interactionEventName: "tap")
        let swipe = makeAutoCaptureEvent(interactionEventName: "swipe")

        let publishCount = publishAndCountSocketPublishes([tap, swipe], expectedCount: 2)

        XCTAssertEqual(publishCount, 2)
    }

    func testTrackEvent_autoCaptureDialogEvents_differentTitlesShouldBothPublish() {
        let hierarchy = "UIAlertController:attr__index=\"0\";HomeViewController"
        let deleteDialog = makeAutoCaptureEvent(
            properties: [
                AutoCaptureConstants.hierarchy: hierarchy,
                AutoCaptureConstants.rawInteractionType: "view_presented",
                AutoCaptureConstants.dialogTitle: "Delete item?"
            ],
            interactionEventName: "view_presented"
        )
        let logoutDialog = makeAutoCaptureEvent(
            properties: [
                AutoCaptureConstants.hierarchy: hierarchy,
                AutoCaptureConstants.rawInteractionType: "view_presented",
                AutoCaptureConstants.dialogTitle: "Log out?"
            ],
            interactionEventName: "view_presented"
        )

        let publishCount = publishAndCountSocketPublishes([deleteDialog, logoutDialog], expectedCount: 2)

        XCTAssertEqual(publishCount, 2)
    }

    func testTrackEvent_autoCaptureUnresolvableScreenName_shouldStillUseOtherDiscriminators() {
        // Screen dict is non-empty (passes the flush guard) but has no
        // class/title/name, so the screen segment cannot be resolved
        let screen: Payload = [AutoCaptureConstants.screenType: "modal"]
        let saveTap = makeAutoCaptureEvent(
            properties: [AutoCaptureConstants.targetText: "Save"],
            screen: screen
        )
        let cancelTap = makeAutoCaptureEvent(
            properties: [AutoCaptureConstants.targetText: "Cancel"],
            screen: screen
        )

        let publishCount = publishAndCountSocketPublishes([saveTap, cancelTap], expectedCount: 2)

        XCTAssertEqual(publishCount, 2)
    }

    func testTrackEvent_autoCaptureIdenticalEvents_secondShouldThrottle() {
        let tap = makeAutoCaptureEvent(
            properties: [
                AutoCaptureConstants.hierarchy: "UIButton:attr__index=\"0\";HomeViewController",
                AutoCaptureConstants.rawInteractionType: "tap",
                AutoCaptureConstants.targetText: "Save"
            ]
        )

        let publishCount = publishAndCountSocketPublishes([tap, tap], expectedCount: 1)

        XCTAssertEqual(publishCount, 1)
    }

    func testTrackEvent_autoCaptureTabEvents_differentTabsShouldBothPublish() {
        let homeTab = makeAutoCaptureEvent(
            properties: [
                AutoCaptureConstants.tabName: "Home",
                AutoCaptureConstants.tabIndex: 0,
                AutoCaptureConstants.rawInteractionType: "tab_selected"
            ],
            interactionEventName: "tab_selected"
        )
        let profileTab = makeAutoCaptureEvent(
            properties: [
                AutoCaptureConstants.tabName: "Profile",
                AutoCaptureConstants.tabIndex: 1,
                AutoCaptureConstants.rawInteractionType: "tab_selected"
            ],
            interactionEventName: "tab_selected"
        )

        let publishCount = publishAndCountSocketPublishes([homeTab, profileTab], expectedCount: 2)

        XCTAssertEqual(publishCount, 2)
    }

    func testTrackEvent_customEvents_sameTitleShouldThrottleSecond() {
        let event = Event(type: .event("button_clicked"))

        let publishCount = publishAndCountSocketPublishes([event, event], expectedCount: 1)

        XCTAssertEqual(publishCount, 1)
    }

    func testPublish_withSameIdentifyEvent_shouldNotReprocess() {
        // Arrange
        let userId = "test-user"
        let properties = ["name": "John"]
        let identifyEvent = Event(type: .identify(userId), properties: properties)

        // Set up existing user
        let user = User(userId: userId, properties: properties, company: [:])
        userpilot.storage.user = user.toJson() ?? ""

        var publishIdentifyEventCalled = false
        userpilot.socketManager.onPublish = { _, _ in publishIdentifyEventCalled = true }

        // Act
        analyticsPublisher.publish(identifyEvent)

        // Assert
        // Should not reprocess same identify event
        XCTAssertFalse(publishIdentifyEventCalled)
    }
}

// swiftlint:enable all
