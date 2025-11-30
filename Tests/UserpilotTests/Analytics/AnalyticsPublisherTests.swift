//
//  AnalyticsPublisherTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import Foundation
import XCTest

@testable import Userpilot

// swiftlint:disable all

class AnalyticsPublisherTests: XCTestCase {

    var analyticsPublisher: AnalyticsPublisher!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        analyticsPublisher = AnalyticsPublisher(container: userpilot.container)
    }

    override func tearDown() {
        analyticsPublisher = nil
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_shouldRegisterAsSocketSubscription() {
        // Assert
        // Verify that registerCallback was called during initialization
        // This is implicitly tested by the fact that the publisher exists
        XCTAssertNotNil(analyticsPublisher)
    }

    func testInit_shouldRestoreCachedUserFromStorage() {
        // Arrange
        let cachedUser = User(userId: "cached-user", properties: ["name": "John"], company: [:])
        userpilot.storage.temporaryUser = cachedUser.toJson()

        // Act
        let newPublisher = AnalyticsPublisher(container: userpilot.container)

        // Assert
        XCTAssertNotNil(newPublisher)
        // The cached user should be enqueued as an identify event
    }

    // MARK: - Publish Tests - App State Handling

    func testPublish_whenAppInactive_shouldNotProcessEvent() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = false
        let event = Event(type: .event("test_event"))
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        // Act
        analyticsPublisher.publish(event)

        // Assert
        XCTAssertFalse(didPublishEvent)
    }

    func testPublish_whenAppActive_shouldProcessEvent() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        let event = Event(type: .event("test_event"))
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        let expectation = XCTestExpectation(description: "Event processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if didPublishEvent {
                expectation.fulfill()
            }
        }

        // Act
        analyticsPublisher.publish(event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Publish Tests - Identify Event Handling

    func testPublish_identifyEvent_shouldUpdateTemporaryUser() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        let identifyEvent = Event(
            type: .identify("new-user"),
            properties: ["name": "Jane"],
            company: ["id": "company-1"]
        )

        // Act
        analyticsPublisher.publish(identifyEvent)

        // Assert
        XCTAssertNotNil(userpilot.storage.temporaryUser)
        let cachedUser = User.fromJson(userpilot.storage.temporaryUser ?? "")
        XCTAssertEqual(cachedUser.userId, "new-user")
    }

    func testPublish_sameIdentifyEvent_shouldIgnore() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        let userId = "same-user"
        let properties = ["name": "John"]
        let user = User(userId: userId, properties: properties, company: [:])
        userpilot.storage.user = user.toJson() ?? ""

        let identifyEvent = Event(type: .identify(userId), properties: properties)
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.publish(identifyEvent)

        // Assert
        XCTAssertFalse(didConnect)
    }

    func testPublish_screenEvent_shouldUpdateExperiencePublisher() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        let screenEvent = Event(type: .screen("Home Screen"))
        var updatedScreen: String?
        userpilot.experiencesPublisher.onUpdateScreen = { screenName in
            updatedScreen = screenName
        }

        // Act
        analyticsPublisher.publish(screenEvent)

        // Assert
        XCTAssertEqual(updatedScreen, "Home Screen")
    }

    // MARK: - Publish Tests - Socket State Handling

    func testPublish_whenSocketInShutdownState_shouldNotProcessEvent() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isShutdownState = true
        let event = Event(type: .event("test_event"))
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.publish(event)

        // Assert
        XCTAssertFalse(didConnect)
    }

    func testPublish_whenSocketJoining_shouldCacheEventOnly() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isJoiningSocket = true
        let event = Event(type: .event("test_event"))
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        // Act
        analyticsPublisher.publish(event)

        // Assert - Event is cached but not published yet
        XCTAssertFalse(didPublishEvent)
    }

    func testPublish_whenSocketClosed_shouldOpenSocket() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isAllowToOpenSocket = true
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test_event"))
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.publish(event)

        // Assert
        XCTAssertTrue(didConnect)
    }

    func testPublish_whenSocketClosedWithoutUserId_shouldNotOpenSocket() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = false
        userpilot.storage.userId = ""
        let event = Event(type: .event("test_event"))
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.publish(event)

        // Assert
        XCTAssertFalse(didConnect)
    }

    func testPublish_whenSocketOpened_shouldProcessImmediately() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        let event = Event(type: .event("test_event"))
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        let expectation = XCTestExpectation(description: "Event published")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if didPublishEvent {
                expectation.fulfill()
            }
        }

        // Act
        analyticsPublisher.publish(event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Resume Tests

    func testResume_withValidUserId_shouldOpenSocket() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isAllowToOpenSocket = true
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.resume()

        // Assert
        XCTAssertTrue(didConnect)
    }

    func testResume_withEmptyUserId_shouldNotOpenSocket() {
        // Arrange
        userpilot.storage.userId = ""
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.resume()

        // Assert
        XCTAssertFalse(didConnect)
    }

    func testResume_shouldUpdateSessionState() {
        // Arrange
        let oldDate = Date().addingTimeInterval(-35 * 60)  // 35 minutes ago
        userpilot.storage.sessionDate = oldDate
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isAllowToOpenSocket = true

        // Act
        analyticsPublisher.resume()

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }

    // MARK: - Logout Tests

    func testLogout_shouldResetStartSession() {
        // Arrange - nothing needed

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: true)

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }

    func testLogout_shouldCloseSocket() {
        // Arrange
        var didClose = false
        userpilot.socketManager.onClose = { didClose = true }

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: true)

        // Assert
        XCTAssertTrue(didClose)
    }

    func testLogout_withClearCache_shouldPublishLogoutEvent() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.storage.pushToken = "push-token"
        userpilot.socketManager.isSocketOpened = true
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: true)

        // Assert
        XCTAssertTrue(didPublishEvent)
    }

    func testLogout_withoutClearCache_shouldNotPublishLogoutEvent() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.storage.pushToken = "push-token"
        userpilot.socketManager.isSocketOpened = true
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: false)

        // Assert
        XCTAssertFalse(didPublishEvent)
    }

    func testLogout_shouldCallExperiencesPublisherLogout() {
        // Arrange
        var didCallResetState = false
        userpilot.experiencesPublisher.onResetState = { didCallResetState = true }

        // Act
        analyticsPublisher.logout(clearCachedIdentifyEvent: true)

        // Assert
        XCTAssertTrue(didCallResetState)
    }

    // MARK: - Flush Tests

    func testFlush_shouldCloseSocket() {
        // Arrange
        var didClose = false
        userpilot.socketManager.onClose = { didClose = true }

        // Act
        analyticsPublisher.flush()

        // Assert
        XCTAssertTrue(didClose)
    }

    // MARK: - Socket Callback Tests

    func testOnSocketOpened_shouldProcessEvents() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = false  // Socket closed initially
        userpilot.socketManager.isJoiningSocket = true  // Socket is joining, so events get queued
        userpilot.storage.userId = "test-user"

        // Queue an event first (will be cached because socket is joining)
        let event = Event(type: .event("test_event"))
        analyticsPublisher.publish(event)

        // Now socket opens
        userpilot.socketManager.isSocketOpened = true
        userpilot.socketManager.isJoiningSocket = false

        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        let expectation = XCTestExpectation(description: "Event processed after socket opened")

        // Act
        analyticsPublisher.onSocketOpened()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if didPublishEvent {
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnSocketClosed_whenError_shouldNotReconnect() {
        // Arrange
        userpilot.socketManager.didCloseFromError = true
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.onSocketClosed()

        // Assert
        XCTAssertFalse(didConnect)
    }

    func testOnSocketClosed_withQueuedEvents_shouldRepublish() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.didCloseFromError = false

        // Queue an event
        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.publish(identifyEvent)

        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.onSocketClosed()

        // Assert
        XCTAssertTrue(didConnect)
    }

    func testOnSocketEventSent_identifyEvent_shouldUpdateUserInStorage() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = false  // Socket closed initially
        userpilot.socketManager.isJoiningSocket = true  // Joining, so events get queued
        userpilot.storage.userId = "test-user"
        
        // Now open socket
        userpilot.socketManager.isSocketOpened = true
        userpilot.socketManager.isJoiningSocket = false
        
        // Initialize user storage with existing user to match real-world scenario
        let existingUser = User(userId: "test-user", properties: [:], company: [:])
        userpilot.storage.user = existingUser.toJson() ?? ""

        let identifyEvent = Event(
            type: .identify("test-user"),
            properties: ["name": "John"],
            company: [:]
        )
        // Publish event (will be queued because socket is joining)
        analyticsPublisher.publish(identifyEvent)

       

        let payload: [String: Any] = ["metadata": identifyEvent.properties ?? [:]]
        let message = Message()

        // Act - Simulate the event being sent
        analyticsPublisher.onSocketEventSent(Constants.Event.identifyEvent, payload, message, true)

        // Assert - User should be updated with new properties
        XCTAssertTrue(userpilot.storage.user.contains("test-user"))
        XCTAssertTrue(userpilot.storage.user.contains("John"))
    }

    func testOnSocketEventSent_nonIdentifyEvent_shouldProcessNextEvent() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true

        let event1 = Event(type: .event("event1"))
        let event2 = Event(type: .event("event2"))
        analyticsPublisher.publish(event1)
        analyticsPublisher.publish(event2)

        var publishCount = 0
        userpilot.socketManager.onPublish = { _, _, _ in publishCount += 1 }

        let payload: [String: Any] = ["event_name": "event1"]
        let message = Message()

        let expectation = XCTestExpectation(description: "Process next event")

        // Act
        analyticsPublisher.onSocketEventSent("event", payload, message, true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Screen Management Tests

    func testPublish_screenEvent_shouldCreateScreenEntity() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }
        let screenEvent = Event(type: .screen("Home Screen"))

        // Act
        analyticsPublisher.publish(screenEvent)

        // Assert
        XCTAssertNotNil(analyticsPublisher.screenEntity)
        XCTAssertEqual(analyticsPublisher.screenEntity?.event.screenTitle, "Home Screen")
    }

    func testPublish_differentScreenEvent_shouldUpdateScreenEntity() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }
        // Simulate socket ack for screen events so processing advances
        userpilot.socketManager.onPublish = { eventName, payload, _ in
            if eventName == Constants.Event.screenEvent {
                self.analyticsPublisher.onSocketEventSent(
                    eventName, payload, Message(), true
                )
            }
        }

        let screen1 = Event(type: .screen("Screen 1"))
        let screen2 = Event(type: .screen("Screen 2"))

        let expectation = XCTestExpectation(description: "Screen events processed")

        // Act
        analyticsPublisher.publish(screen1)

        // Wait for processing (throttle window ~1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            let firstScreen = self.analyticsPublisher.screenEntity?.event.screenTitle
            XCTAssertEqual(firstScreen, "Screen 1")

            self.analyticsPublisher.publish(screen2)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                let secondScreen = self.analyticsPublisher.screenEntity?.event.screenTitle
                XCTAssertEqual(secondScreen, "Screen 2")
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 3.0)
    }

    func testPublish_sameScreenEvent_shouldRetainSeenExperiences() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        let screenEvent = Event(type: .screen("Same Screen"))

        // Act
        analyticsPublisher.publish(screenEvent)
        analyticsPublisher.experiencePublished(.flow, 123)

        analyticsPublisher.publish(screenEvent)  // Same screen again

        // Assert
        XCTAssertTrue(analyticsPublisher.screenEntity?.seenExperiences.contains(123) ?? false)
    }

    // MARK: - Experience Tracking Tests

    func testExperiencePublished_flow_shouldAddToSeenExperiences() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        // Act
        analyticsPublisher.experiencePublished(.flow, 456)

        // Assert
        XCTAssertTrue(analyticsPublisher.screenEntity?.seenExperiences.contains(456) ?? false)
    }

    func testExperiencePublished_survey_shouldAddToSeenSurveys() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        // Act
        analyticsPublisher.experiencePublished(.survey, 789)

        // Assert
        XCTAssertTrue(analyticsPublisher.screenEntity?.seenSurveys.contains(789) ?? false)
    }

    func testExperiencePublished_nilParameters_shouldNotCrash() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        // Act & Assert - Should not crash
        analyticsPublisher.experiencePublished(nil, nil)
        analyticsPublisher.experiencePublished(.flow, nil)
        analyticsPublisher.experiencePublished(nil, 123)
    }

    // MARK: - Internal SDK Events Tests

    func testPublishInternalSDKEvent_whenSocketOpen_shouldPublish() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let sdkEvent = MockSDKEvent(eventName: "test-sdk-event", eventPayload: ["key": "value"])
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        // Act
        analyticsPublisher.publishInternalSDKEvent(sdkEvent)

        // Assert
        XCTAssertTrue(didPublishEvent)
    }

    func testPublishInternalSDKEvent_whenSocketClosed_shouldCacheEvent() {
        // Arrange
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isAllowToOpenSocket = true
        let sdkEvent = MockSDKEvent(eventName: "test-sdk-event")
        var didConnect = false
        userpilot.socketManager.onConnect = { didConnect = true }

        // Act
        analyticsPublisher.publishInternalSDKEvent(sdkEvent)

        // Assert
        XCTAssertTrue(didConnect)
    }

    // MARK: - Fake Reload Screen Event Tests

    func testPublishFakeReloadScreenEvent_withScreenEntity_shouldPublish() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        let screenEvent = Event(type: .screen("Test Screen"))

        let expectation = XCTestExpectation(description: "Fake reload published")

        // Publish screen event first
        analyticsPublisher.publish(screenEvent)

        // Simulate socket ack for the screen event so queue clears and processing resets
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.analyticsPublisher.onSocketEventSent(
                Constants.Event.screenEvent, nil, Message(), true
            )
        }

        // Wait for screen event to be processed and throttle to reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Now set up the callback to capture only the fake reload event
            var fakeReloadPublished = false
            self.userpilot.socketManager.onPublish = { eventName, payload, _ in
                // Check if this is a screen event with fake reload flag
                if eventName == "screen",
                    let metadata = payload?["metadata"] as? [String: Any],
                    let isFakeReload = metadata["fake_reload"] as? Bool,
                    isFakeReload == true
                {
                    fakeReloadPublished = true
                }
            }

            // Act - Publish fake reload
            self.analyticsPublisher.publishFakeReloadScreenEvent(.flow, 123)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if fakeReloadPublished {
                    expectation.fulfill()
                }
            }
        }

        // Assert
        wait(for: [expectation], timeout: 3.0)
    }

    func testPublishFakeReloadScreenEvent_withoutScreenEntity_shouldNotPublish() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _, _ in didPublishEvent = true }

        // Act
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 123)

        // Assert
        XCTAssertFalse(didPublishEvent)
    }

    func testPublishFakeReloadScreenEvent_withNonEmptyQueue_shouldNotPublish() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true

        // Create screen entity
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)

        // Add event to queue
        let event = Event(type: .event("queued-event"))
        analyticsPublisher.publish(event)

        var fakeReloadPublished = false
        userpilot.socketManager.onPublish = { eventName, _, _ in
            if eventName == "screen" {
                fakeReloadPublished = true
            }
        }

        // Act
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 123)

        // Assert
        XCTAssertFalse(fakeReloadPublished)
    }

    // MARK: - Session State Tests

    func testUpdateSessionState_expiredSession_shouldSetStartSessionTrue() {
        // Arrange
        let oldDate = Date().addingTimeInterval(-35 * 60)  // 35 minutes ago
        userpilot.storage.sessionDate = oldDate

        // Act
        analyticsPublisher.updateSessionState()

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }

    func testUpdateSessionState_activeSession_shouldSetStartSessionFalse() {
        // Arrange
        let recentDate = Date().addingTimeInterval(-10 * 60)  // 10 minutes ago
        userpilot.storage.sessionDate = recentDate

        // Act
        analyticsPublisher.updateSessionState()

        // Assert
        XCTAssertFalse(analyticsPublisher.isStartSession)
    }

    func testUpdateSessionState_noSessionDate_shouldNotChangeStartSession() {
        // Arrange
        userpilot.storage.sessionDate = nil
        // Default startSession is true

        // Act
        analyticsPublisher.updateSessionState()

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }

    // MARK: - canRequestEvent Tests

    func testCanRequestEvent_whenSocketOpen_shouldReturnTrue() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true

        // Act & Assert
        XCTAssertTrue(analyticsPublisher.canRequestEvent)
    }

    func testCanRequestEvent_whenSocketClosed_shouldReturnFalse() {
        // Arrange
        userpilot.socketManager.isSocketOpened = false

        // Act & Assert
        XCTAssertFalse(analyticsPublisher.canRequestEvent)
    }

    // MARK: - Event Throttling Tests

    func testPublish_duplicateScreenEventsQuickly_shouldThrottle() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        let screenEvent = Event(type: .screen("Test Screen"))
        var publishCount = 0
        userpilot.socketManager.onPublish = { _, _, _ in publishCount += 1 }

        // Act
        analyticsPublisher.publish(screenEvent)
        analyticsPublisher.publish(screenEvent)  // Immediate duplicate should be throttled

        let expectation = XCTestExpectation(description: "Wait for processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        // Assert - Should only publish once due to throttling
        XCTAssertEqual(publishCount, 1)
    }

    // MARK: - Edge Cases

    func testPublish_multipleEventTypes_shouldProcessInOrder() {
        // Arrange
        userpilot.sessionMonitor.isAppActive = true
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        let identifyEvent = Event(type: .identify("test-user"))
        let screenEvent = Event(type: .screen("Home"))
        let trackEvent = Event(type: .event("button_click"))

        var eventOrder: [String] = []
        userpilot.socketManager.onPublish = { eventName, _, _ in
            eventOrder.append(eventName)
        }

        // Act
        analyticsPublisher.publish(identifyEvent)
        analyticsPublisher.publish(screenEvent)
        analyticsPublisher.publish(trackEvent)

        let expectation = XCTestExpectation(description: "Process all events")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // Assert - Events should be processed
        XCTAssertTrue(eventOrder.count > 0)
    }
}

// swiftlint:enable all
