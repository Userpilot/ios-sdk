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

final class AnalyticsPublisherTests: XCTestCase {

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

    private func acknowledge(_ event: String, _ payload: Payload, _ message: Message, _ success: Bool) {
        analyticsPublisher.mockWaitForQueue()
        XCTAssertTrue(userpilot.socketManager.requests.contains { $0.event == event && $0.shouldSend() }, "No captured request for \(event); captured: \(userpilot.socketManager.requests.map(\.event))")
        userpilot.socketManager.completeNext(event, payload, message, success)
        analyticsPublisher.testSettle()
    }

    func testStaleACKCannotDequeueIdenticalRetryAfterReconnect() throws {
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .event("Purchase")))
        let original = try XCTUnwrap(userpilot.socketManager.requests.last)
        userpilot.socketManager.didCloseFromError = true
        userpilot.socketManager.isSocketOpened = false
        analyticsPublisher.testOnSocketClosed()
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        let retry = try XCTUnwrap(userpilot.socketManager.requests.last)
        XCTAssertFalse(original.shouldSend())
        XCTAssertTrue(retry.shouldSend())
        original.completion?(Message(), true)
        analyticsPublisher.testSettle()
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.eventTitle), ["Purchase"])
        retry.completion?(Message(), true)
        analyticsPublisher.testSettle()
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    // MARK: - Publish Method Tests

    func testPublish_identifyEvent_shouldCacheEventAndUpdateStorage() {
        userpilot.storage.userId = ""
        userpilot.socketManager.isJoiningSocket = true
        let identify = Event(
            type: .identify("user-123"),
            properties: ["plan": "pro"],
            company: ["id": "company-123"]
        )

        analyticsPublisher.testPublish(identify)

        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.userId, "user-123")
        XCTAssertEqual(queued.first?.properties?["plan"] as? String, "pro")
        XCTAssertEqual(queued.first?.company?["id"] as? String, "company-123")
        let pending = User.fromJson(userpilot.storage.temporaryUser.orEmpty())
        XCTAssertEqual(pending.userId, "user-123")
        XCTAssertEqual(pending.properties["plan"] as? String, "pro")
        XCTAssertEqual(pending.company["id"] as? String, "company-123")
        XCTAssertEqual(userpilot.storage.userId, "user-123")
    }

    func testPublish_userSwitch_shouldDropOldQueuedEventsAtAdmission() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.testPublish(Event(type: .event("old-user-event")))

        analyticsPublisher.testPublish(Event(type: .identify("user-b")))

        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertEqual(userpilot.storage.userId, "user-b")
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.userId, "user-b")
        XCTAssertTrue(userpilot.offlineEventsHandler.didClearLocalEvents)
        XCTAssertTrue(userpilot.container.resolve(UserSessionStateManaging.self).isUserSwitching())
    }

    func testPublish_userSwitchWhileNetworkStatePending_shouldDropOldInitialEvents() {
        userpilot.storage.userId = "user-a"
        userpilot.networkMonitor.isReady = false
        analyticsPublisher.testPublish(Event(type: .event("old-user-event")))

        analyticsPublisher.testPublish(Event(type: .identify("user-b")))

        let queued = analyticsPublisher.mockGetInitialQueue()
        XCTAssertEqual(userpilot.storage.userId, "user-b")
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.userId, "user-b")
    }

    func testNetworkReady_afterPendingUserSwitch_shouldRouteOnlyNewUserEvents() {
        userpilot.storage.userId = "user-a"
        userpilot.networkMonitor.isReady = false
        analyticsPublisher.testPublish(Event(type: .event("old-user-event")))
        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        analyticsPublisher.testPublish(Event(type: .screen("user-b-screen")))

        userpilot.networkMonitor.isReady = true
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.networkMonitorDidUpdate(
            isReady: true,
            isNetworkAvailable: true
        )

        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertTrue(analyticsPublisher.mockGetInitialQueue().isEmpty)
        XCTAssertEqual(queued.count, 2)
        XCTAssertEqual(queued.first?.userId, "user-b")
        XCTAssertEqual(queued.last?.screenTitle, "user-b-screen")
    }

    func testPublish_rapidUserSwitch_shouldKeepOnlyLatestIdentify() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isJoiningSocket = true

        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        analyticsPublisher.testPublish(Event(type: .screen("user-b-screen")))
        analyticsPublisher.testPublish(Event(type: .identify("user-c"), properties: ["plan": "pro"]))

        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertEqual(userpilot.storage.userId, "user-c")
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.userId, "user-c")
        XCTAssertEqual(queued.first?.properties?["plan"] as? String, "pro")
    }

    func testPublish_userSwitchShutdown_shouldQueueFollowingNewUserEvents() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isSocketOpened = true

        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isShutdownState = true
        analyticsPublisher.testPublish(Event(type: .screen("user-b-screen")))

        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertEqual(userpilot.storage.userId, "user-b")
        XCTAssertEqual(queued.count, 2)
        XCTAssertEqual(queued.first?.userId, "user-b")
        XCTAssertEqual(queued.last?.screenTitle, "user-b-screen")
    }

    func testPublish_screenEvent_shouldSetupScreenSessionStateMachine() {
        // Arrange
        let screenEvent = Event(type: .screen("Home Screen"))
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }

        // Act
        analyticsPublisher.testPublish(screenEvent)

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
        analyticsPublisher.testPublish(screenEvent)

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
        analyticsPublisher.testPublish(screenEvent)

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

        // Act: the test helper waits for admission on the real owner queue.
        analyticsPublisher.testPublish(customEvent)

        XCTAssertTrue(didPublishEvent)
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.eventTitle), ["button_clicked"])
    }

    func testPublish_whenSocketNotOpened_shouldCacheEvent() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isSocketOpened = false
        userpilot.storage.userId = "test-user"

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.testPublish(customEvent)

        // Assert
        XCTAssertTrue(connectCalled)
    }

    func testPublish_whenSocketIsJoining_shouldCacheEvent() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isJoiningSocket = true

        // Act
        analyticsPublisher.testPublish(customEvent)

        // Assert
        // Event should be cached in the live queue, not sent immediately.
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().count, 1)
    }

    func testPublish_whenSocketInShutdownState_keepsEventUntilSocketAcceptsReconnect() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isShutdownState = true
        var didSocketConnect = false
        userpilot.socketManager.onConnect = {
            didSocketConnect = true
        }

        // Act
        analyticsPublisher.testPublish(customEvent)

        // Assert
        // SocketManager owns connection admission; analytics retains the event until it opens.
        XCTAssertTrue(didSocketConnect)
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.eventTitle), ["test_event"])
        XCTAssertTrue(userpilot.socketManager.requests.isEmpty)
    }

    // MARK: - Flush Tests

    func testFlush_shouldUpdateSocketStateAndFlushQueue() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        var closeCalled = false
        userpilot.socketManager.onClose = { closeCalled = true }

        // Act
        analyticsPublisher.testFlush()

        // Assert
        XCTAssertTrue(closeCalled)
    }

    // MARK: - Resume Tests

    func testFlush_keepsOnlyTheLatestIdentifyWhenSwitchingUsers() {
        assertFlushKeepsLatestIdentify(latestUserId: "newest-user")
    }

    func testFlush_keepsTheLatestIdentifyWhenSwitchingBackToTheOriginalUser() {
        assertFlushKeepsLatestIdentify(latestUserId: "old-user")
    }

    private func assertFlushKeepsLatestIdentify(latestUserId: String) {
        arrangeReloadableScreen(title: "Home", userId: "old-user")
        userpilot.storage.sessionDate = Date()
        var closeCalled = false
        userpilot.socketManager.onClose = { closeCalled = true }
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.testPublish(Event(type: .event("Before switch")))
        analyticsPublisher.testPublish(Event(type: .identify("intermediate-user"), properties: ["plan": "basic"]))
        analyticsPublisher.testPublish(Event(type: .screen("Checkout")))
        analyticsPublisher.testPublish(Event(type: .identify(latestUserId), properties: ["plan": "pro"]))
        analyticsPublisher.testPublish(Event(
            type: .identify(latestUserId), properties: ["plan": "enterprise"], company: ["id": "latest-company"]))
        analyticsPublisher.testPublish(Event(type: .event("Purchase"), properties: ["amount": 42]))
        userpilot.sessionMonitor.isAppActive = false

        analyticsPublisher.testFlush()

        XCTAssertTrue(closeCalled)
        analyticsPublisher.testOnSocketClosed()
        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.userId, latestUserId)
        XCTAssertEqual(queued.first?.properties?["plan"] as? String, "enterprise")
        let cached = User.fromJson(userpilot.storage.temporaryUser.orEmpty())
        XCTAssertEqual(cached.userId, latestUserId)
        XCTAssertEqual(cached.properties["plan"] as? String, "enterprise")
        XCTAssertEqual(cached.company["id"] as? String, "latest-company")

        var sent: [(String, Payload)] = []
        userpilot.socketManager.onPublish = { sent.append(($0, $1)) }
        userpilot.socketManager.isJoiningSocket = false
        userpilot.socketManager.isSocketOpened = true
        userpilot.sessionMonitor.isAppActive = true
        analyticsPublisher.testResume()
        analyticsPublisher.testOnSocketOpened()
        XCTAssertEqual(userpilot.storage.userId, latestUserId)
        XCTAssertEqual(sent.map { $0.0 }, [Constants.Event.identifyEvent])
        let metadata = sent.first?.1?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(metadata?["plan"] as? String, "enterprise")
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)
        XCTAssertEqual(sent.map { $0.0 }, [Constants.Event.identifyEvent, Constants.Event.screenEvent])
        XCTAssertEqual(sent.last?.1?[Constants.Analytics.screenTitleProperty] as? String, "Home")
        let screenMetadata = sent.last?.1?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(screenMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
        XCTAssertEqual(screenMetadata?[Constants.Analytics.fakeReload] as? Bool, false)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
        XCTAssertEqual(sent.count, 2)
    }

    func testResume_shouldConnectSocketWhenUserIdExists() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isJoiningSocket = false

        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }

        // Act
        analyticsPublisher.testResume()

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
        analyticsPublisher.testResume()

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
        analyticsPublisher.testResume()

        // Assert
        XCTAssertFalse(connectCalled)
    }

    // MARK: - Reset Tests

    func testReset_shouldResetStartSessionFlag() {
        userpilot.storage.sessionDate = Date().addingTimeInterval(-60)
        analyticsPublisher.testResume()
        analyticsPublisher.mockWaitForQueue()
        XCTAssertFalse(analyticsPublisher.isStartSession)

        analyticsPublisher.testReset()

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
        analyticsPublisher.logout()

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
        analyticsPublisher.logout()

        // Assert
        XCTAssertTrue(publishLogoutEventCalled)
    }

    func testLogout_shouldClearInitialQueue() {
        userpilot.networkMonitor.isReady = false
        analyticsPublisher.testPublish(Event(type: .identify("user-a")))
        XCTAssertEqual(analyticsPublisher.mockGetInitialQueue().count, 1)

        analyticsPublisher.logout()

        XCTAssertTrue(analyticsPublisher.mockGetInitialQueue().isEmpty)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    // MARK: - Socket Subscription Tests

    func testOnSocketOpened_shouldFlushPriorityEvents() {
        // Arrange
        userpilot.storage.userId = ""
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isJoiningSocket = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }

        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.testPublish(identifyEvent)

        userpilot.socketManager.isSocketOpened = true
        userpilot.socketManager.isJoiningSocket = false
        var didPublishEvent = false
        userpilot.socketManager.onPublish = { _, _ in
            didPublishEvent = true
        }

        // Act
        analyticsPublisher.testOnSocketOpened()

        // Assert
        // Would need to verify that cached events were flushed
        XCTAssertTrue(didPublishEvent)
    }

    func testOnSocketClosed_shouldHandleReconnection() {
        // Arrange
        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.testPublish(identifyEvent)
        userpilot.socketManager.didCloseFromError = false

        var didSocketConnect = false
        userpilot.socketManager.onConnect = {
            didSocketConnect = true
        }

        // Act
        analyticsPublisher.testOnSocketClosed()

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
        analyticsPublisher.testOnSocketClosed()

        // Assert
        XCTAssertFalse(didSocketConnect)
    }

    func testIdentifyAcknowledgementClearsOnlyPendingIdentifySnapshot() {
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .identify("test-user"), properties: ["plan": "pro"]))
        XCTAssertEqual(User.fromJson(userpilot.storage.temporaryUser.orEmpty()).properties["plan"] as? String, "pro")
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().count, 1)

        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)

        XCTAssertEqual(userpilot.storage.userId, "test-user")
        XCTAssertNil(userpilot.storage.temporaryUser)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
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
        analyticsPublisher.testPublishInternalSDKEvent(sdkEvent)

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
        analyticsPublisher.testPublishInternalSDKEvent(sdkEvent)

        // Assert
        // Should not publish experience event when socket is closed
        XCTAssertFalse(didPublishEvent)
    }

    // MARK: - Push Token vs Offline Sync

    private var pushTokenEventName: String { SDKEventsName.pushNotificationToken.rawValue }

    private func makePushTokenEvent() -> PushNotificationTokenEvent {
        PushNotificationTokenEvent(
            appToken: "NX-00000",
            userId: "test-user-123",
            token: "device-push-token"
        )
    }

    func testPublishInternalSDKEvent_pushTokenWithStoredOfflineEvents_shouldWaitForSyncToFinish() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        userpilot.offlineEventsHandler.hasCachedEvents = true
        userpilot.offlineEventsHandler.holdRestoreCompletion = true
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { eventName, _ in
            publishedEvents.append(eventName)
        }

        // Act
        analyticsPublisher.testPublishInternalSDKEvent(makePushTokenEvent())

        // Assert - the offline batch owns the wire, the token does not overtake it
        XCTAssertFalse(publishedEvents.contains(pushTokenEventName))

        // Act - the batch lands and the cached SDK events drain
        userpilot.offlineEventsHandler.finishRestore()
        analyticsPublisher.testSettle()

        // Assert
        XCTAssertTrue(publishedEvents.contains(pushTokenEventName))
    }

    func testPublishInternalSDKEvent_pushTokenWithNoOfflineEvents_shouldStillSendInTheSamePass() {
        // Arrange - taking the cached route must not delay the token when nothing is syncing
        userpilot.socketManager.isSocketOpened = true
        userpilot.offlineEventsHandler.hasCachedEvents = false
        var publishedPayload: [String: Any]?
        userpilot.socketManager.onPublish = { eventName, payload in
            if eventName == self.pushTokenEventName { publishedPayload = payload }
        }

        // Act
        analyticsPublisher.testPublishInternalSDKEvent(makePushTokenEvent())

        // Assert
        XCTAssertEqual(publishedPayload?["token"] as? String, "device-push-token")
        XCTAssertEqual(publishedPayload?["user_id"] as? String, "test-user-123")
        XCTAssertEqual(publishedPayload?["app_token"] as? String, "NX-00000")
    }

    func testPublishInternalSDKEvent_pushTokenWhileSocketClosed_shouldSendOnceSocketOpens() {
        // Arrange
        userpilot.socketManager.isSocketOpened = false
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { eventName, _ in
            publishedEvents.append(eventName)
        }
        analyticsPublisher.testPublishInternalSDKEvent(makePushTokenEvent())
        XCTAssertFalse(publishedEvents.contains(pushTokenEventName))

        // Act
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        // Assert
        XCTAssertTrue(publishedEvents.contains(pushTokenEventName))
    }

    func testPublishInternalSDKEvent_pushTokenDrain_shouldNotReCacheTheEvent() {
        // Arrange - the drain must send directly, or it re-enters the cached route forever
        userpilot.socketManager.isSocketOpened = true
        var publishCount = 0
        userpilot.socketManager.onPublish = { eventName, _ in
            if eventName == self.pushTokenEventName { publishCount += 1 }
        }

        // Act
        analyticsPublisher.testPublishInternalSDKEvent(makePushTokenEvent())
        analyticsPublisher.testOnSocketOpened()

        // Assert - sent exactly once, and the second drain found an empty cache
        XCTAssertEqual(publishCount, 1)
    }

    func testPublishInternalSDKEvent_contentEventWithStoredOfflineEvents_shouldWaitForSyncToFinish() {
        // Arrange - every internal SDK event queues behind a syncing offline batch
        userpilot.socketManager.isSocketOpened = true
        userpilot.offlineEventsHandler.hasCachedEvents = true
        userpilot.offlineEventsHandler.holdRestoreCompletion = true
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { eventName, _ in
            publishedEvents.append(eventName)
        }
        let contentEventName = SDKEventsName.fetchExperienceContent.rawValue
        let contentEvent = MockSDKEvent(eventName: contentEventName)

        // Act
        analyticsPublisher.testPublishInternalSDKEvent(contentEvent)

        // Assert
        XCTAssertFalse(publishedEvents.contains(contentEventName))

        // Act - the batch lands and the cached SDK events drain
        userpilot.offlineEventsHandler.finishRestore()
        analyticsPublisher.testSettle()

        // Assert
        XCTAssertTrue(publishedEvents.contains(contentEventName))
    }

    // MARK: - Cached SDK Event Drain

    func testProcessSDKEvent_multipleCachedEvents_shouldDrainInPublishOrder() {
        // Arrange - the cache is a FIFO queue: events must reach the backend in the order
        // they were published, whatever the storage behind it.
        userpilot.socketManager.isSocketOpened = false
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { eventName, _ in
            publishedEvents.append(eventName)
        }
        ["sdk-event-1", "sdk-event-2", "sdk-event-3"].forEach {
            analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: $0))
        }
        XCTAssertTrue(publishedEvents.isEmpty)

        // Act
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        // Assert
        XCTAssertEqual(publishedEvents, ["sdk-event-1", "sdk-event-2", "sdk-event-3"])
    }

    func testProcessSDKEvent_socketClosesMidDrain_shouldKeepTheRemainingEventCached() {
        // Arrange - the drain checks socket readiness *before* taking an event, so a socket
        // that drops mid-drain leaves the rest cached instead of swallowing them. Popping
        // first and discovering the closed socket afterwards would lose the event.
        userpilot.socketManager.isSocketOpened = false
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { [weak userpilot] eventName, _ in
            publishedEvents.append(eventName)
            // The socket drops as soon as the first event goes out
            userpilot?.socketManager.isSocketOpened = false
        }
        ["sdk-event-1", "sdk-event-2"].forEach {
            analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: $0))
        }

        // Act
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        // Assert - only the first went out, and the re-drive on the empty queue settled
        // instead of spinning on the still-cached second event
        XCTAssertEqual(publishedEvents, ["sdk-event-1"])

        // Act - the socket comes back
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        // Assert - the second event survived the closed window
        XCTAssertEqual(publishedEvents, ["sdk-event-1", "sdk-event-2"])
    }

    /// Losing the network with an experience on screen produces an error close, and Phoenix keeps
    /// retrying, so the close repeats. Internal SDK events are held only in memory — unlike
    /// analytics events they are never written to the offline database — so dropping them on an
    /// error close would lose the dismissal for good and the backend would serve the dismissed
    /// content again. A transport error is not a teardown: the user has not changed and the socket
    /// is expected back.
    func testOnSocketClosed_afterASocketError_shouldKeepCachedSDKEventsForTheReconnect() {
        // Arrange — the network died and a content dismissal was cached
        userpilot.socketManager.isSocketOpened = false
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { eventName, _ in
            publishedEvents.append(eventName)
        }
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "content-dismissed"))
        XCTAssertTrue(publishedEvents.isEmpty)

        // Act — a reconnect attempt fails and the channel reports the error close
        userpilot.socketManager.didCloseFromError = true
        analyticsPublisher.testOnSocketClosed()

        // Act — the connection comes back
        userpilot.socketManager.didCloseFromError = false
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        // Assert — the dismissal still reaches the backend
        XCTAssertEqual(publishedEvents, ["content-dismissed"])
    }

    /// A logout *is* a teardown, so the opposite has to hold too: the previous session's cached
    /// SDK events must not leak into the next one.
    func testLogout_shouldDropCachedSDKEvents() {
        // Arrange — a cached SDK event and a closed socket
        userpilot.socketManager.isSocketOpened = false
        var publishedEvents: [String] = []
        userpilot.socketManager.onPublish = { eventName, _ in
            publishedEvents.append(eventName)
        }
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "content-dismissed"))

        // Act — the SDK is torn down
        analyticsPublisher.logout()

        // Act — a socket opens for the next session
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        // Assert — the previous session's event does not leak into it
        XCTAssertTrue(publishedEvents.isEmpty)
    }

    func testOfflineUserSwitch_dropsOldSDKRequestsAndKeepsNewRequests() {
        userpilot.storage.userId = "user-a"
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        let published = recordPublishedEvents()
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_content"))
        analyticsPublisher.testPublish(Event(type: .event("old-user-event")))

        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_theme"))

        XCTAssertEqual(userpilot.storage.userId, "user-b")
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.count, 1)
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.first?.event.userId, "user-b")
        userpilot.offlineEventsHandler.shouldSaveOffline = false
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        XCTAssertEqual(published(), ["get_mobile_theme"])
    }

    func testDisconnectedUserSwitch_dropsOldSDKRequestsAndKeepsIdentify() {
        userpilot.storage.userId = "user-a"
        let published = recordPublishedEvents()
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_content"))

        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        XCTAssertEqual(userpilot.storage.userId, "user-b")
        XCTAssertEqual(published(), [Constants.Event.identifyEvent])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().first?.userId, "user-b")
    }

    func testUserSwitchSocketClose_shouldReconnectWithoutReplayingQueuedIdentify() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isShutdownState = true
        analyticsPublisher.testPublish(Event(type: .screen("user-b-screen")))

        var connectCount = 0
        userpilot.socketManager.onConnect = { connectCount += 1 }
        userpilot.socketManager.isShutdownState = false
        analyticsPublisher.testOnSocketClosed()

        let queued = analyticsPublisher.mockGetEventsToFlush()
        XCTAssertEqual(connectCount, 1)
        XCTAssertEqual(queued.count, 2)
        XCTAssertEqual(queued.first?.userId, "user-b")
        XCTAssertEqual(queued.last?.screenTitle, "user-b-screen")
        let state = userpilot.container.resolve(UserSessionStateManaging.self).getCurrentState()
        guard case .userSwitching = state else {
            XCTFail("Socket close must not advance identify state before the identify is sent")
            return
        }
    }

    func testUserSwitchSocketClose_whileInactive_shouldWaitForResume() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.publish(Event(type: .identify("user-b")))

        var connectCount = 0
        userpilot.socketManager.onConnect = { connectCount += 1 }
        userpilot.socketManager.isSocketOpened = false
        userpilot.sessionMonitor.isAppActive = false
        analyticsPublisher.testOnSocketClosed()

        XCTAssertEqual(connectCount, 0)
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().first?.userId, "user-b")

        userpilot.sessionMonitor.isAppActive = true
        analyticsPublisher.testResume()
        XCTAssertEqual(connectCount, 1)
    }

    func testUserSwitch_shouldSendIdentifyBeforeNewUserSDKRequests() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isShutdownState = true
        analyticsPublisher.testPublishInternalSDKEvent(
            MockSDKEvent(eventName: "new-user-content-request")
        )

        let published = recordPublishedEvents()
        userpilot.socketManager.isShutdownState = false
        analyticsPublisher.testOnSocketClosed()
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        XCTAssertEqual(published(), [Constants.Event.identifyEvent])
        acknowledge(
            Constants.Event.identifyEvent, nil, Message(), true
        )
        XCTAssertEqual(
            published(),
            [Constants.Event.identifyEvent, "new-user-content-request"]
        )
    }

    func testResumeWithQueuedUserSwitch_keepsNewUserSDKRequestsBehindIdentify() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_content"))
        let published = recordPublishedEvents()

        analyticsPublisher.testResume()
        userpilot.socketManager.isJoiningSocket = false
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        XCTAssertEqual(userpilot.storage.userId, "user-b")
        XCTAssertEqual(published(), [Constants.Event.identifyEvent])
        acknowledge(
            Constants.Event.identifyEvent, nil, Message(), true
        )
        XCTAssertEqual(
            published(),
            [Constants.Event.identifyEvent, "get_mobile_content"]
        )
    }

    func testAppLogout_dropsQueuedIdentifyAndSDKRequests() {
        userpilot.storage.userId = "user-a"
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.testPublish(Event(type: .identify("user-b")))
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_content"))
        let published = recordPublishedEvents()

        analyticsPublisher.logout()

        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
        userpilot.socketManager.isJoiningSocket = false
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        XCTAssertTrue(published().isEmpty)
    }

    func testOfflineIdentifyForSameUser_preservesCachedSDKRequests() {
        userpilot.storage.userId = "user-a"
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        let published = recordPublishedEvents()
        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_content"))

        analyticsPublisher.testPublish(Event(type: .identify("user-a")))
        userpilot.offlineEventsHandler.shouldSaveOffline = false
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()

        XCTAssertEqual(published(), ["get_mobile_content"])
    }

    func testIsExperienceSeen_shouldUseSeenSetForContentType() throws {
        // Arrange — the screen session (which owns the seen sets) is only created once the
        // screen event actually goes out, which requires an open socket.
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Test Screen")))
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        let survey = MockContentFactory.makeSurveyContent(id: 456)

        // Act
        analyticsPublisher.experiencePublished(.flow, flow.id)
        analyticsPublisher.experiencePublished(.survey, survey.id)

        // Assert — each type reads its own seen set, and an unseen id stays unseen
        XCTAssertTrue(analyticsPublisher.isExperienceSeen(.flow(content: flow)))
        XCTAssertTrue(analyticsPublisher.isExperienceSeen(.survey(content: survey)))
        XCTAssertFalse(
            analyticsPublisher.isExperienceSeen(
                .survey(content: MockContentFactory.makeSurveyContent(id: 999))
            )
        )
    }

    /// A screen tracked while offline is only persisted, never published, so the seen sets that
    /// suppress already-shown content have to be reset here too. Without it, content shown before
    /// the connection dropped stays suppressed when the user navigates away and comes back.
    func testPublish_offlineScreenChange_shouldClearSeenContent() throws {
        // Arrange — a flow already shown on the current screen
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen X")))
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        analyticsPublisher.experiencePublished(.flow, flow.id)
        XCTAssertTrue(analyticsPublisher.isExperienceSeen(.flow(content: flow)))

        // Act — the user navigates to another screen with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen Y")))

        // Assert — the flow is eligible again, and the screen event is still only stored
        XCTAssertFalse(analyticsPublisher.isExperienceSeen(.flow(content: flow)))
        XCTAssertEqual(analyticsPublisher.screenSessionStateMachine?.event.screenTitle, "Screen Y")
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.count, 1)
    }

    /// Re-entering the same screen is not navigation, so what was shown there stays suppressed.
    func testPublish_offlineSameScreen_shouldKeepSeenContent() throws {
        // Arrange — a flow already shown on the current screen
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen X")))
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        analyticsPublisher.experiencePublished(.flow, flow.id)

        // Act — the same screen is tracked again with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen X")))

        // Assert — it is still recorded as seen
        XCTAssertTrue(analyticsPublisher.isExperienceSeen(.flow(content: flow)))
    }

    /// Dismissing a Userpilot experience makes the host surface re-emit its screen event. Online
    /// that repeat is dropped, because the dismissal already sent a fake reload for the same
    /// screen. Persisting it while offline replayed it to the backend as a genuine screen view,
    /// making it re-evaluate content for a screen the user never actually re-entered.
    func testPublish_offlineSameScreenAfterAnExperienceClosed_shouldNotStoreTheRepeat() {
        // Arrange — the user is on "Screen X" and an experience has just been dismissed there,
        // which is what leaves `canRequestScreenEvent()` reporting false
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen X")))
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return false }

        // Act — the host surface re-emits the same screen with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen X")))

        // Assert — nothing is persisted, and the screen session still tracks the screen
        XCTAssertTrue(userpilot.offlineEventsHandler.savedEvents.isEmpty)
        XCTAssertEqual(analyticsPublisher.screenSessionStateMachine?.event.screenTitle, "Screen X")
    }

    /// The cooldown suppresses repeats, never real navigation — that would lose the screen.
    func testPublish_offlineNavigationAfterAnExperienceClosed_shouldStillBeStored() {
        // Arrange — the user is on "Screen X" and an experience has just been dismissed there
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen X")))
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return false }

        // Act — the user navigates to another screen with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.testPublish(Event(type: .screen("Screen Y")))

        // Assert — the navigation is persisted
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.count, 1)
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.first?.event.screenTitle, "Screen Y")
    }

    func testIsExperienceSeen_shouldNotCrossTypesForTheSameNumericId() throws {
        // Arrange — the screen session (which owns the seen sets) is only created once the
        // screen event actually goes out, which requires an open socket.
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Test Screen")))
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )

        // Act — only the Flow is marked seen
        analyticsPublisher.experiencePublished(.flow, flow.id)

        // Assert — a Survey sharing that id must not inherit the Flow's seen state
        XCTAssertTrue(analyticsPublisher.isExperienceSeen(.flow(content: flow)))
        XCTAssertFalse(
            analyticsPublisher.isExperienceSeen(
                .survey(content: MockContentFactory.makeSurveyContent(id: flow.id))
            )
        )
    }

    func testIsExperienceSeen_shouldReturnFalseForNPS() throws {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Test Screen")))
        let nps = try XCTUnwrap(
            MockContentFactory.makeNPSContentPayload()
                .toJSONString()?
                .toNPSContent()?
                .npsContent
        )

        // Assert — NPS dedup is owned by ExperiencesPublisher, so this always reports unseen
        XCTAssertFalse(analyticsPublisher.isExperienceSeen(.nps(content: nps)))
    }

    func testPublishFakeReloadScreenEvent_shouldPublishWhenScreenSessionStateMachineExists() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.testPublish(screenEvent)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        let expectation = XCTestExpectation(description: "Wait for delayed fake reload publish")

        var publishScreenEventCalled = false
        userpilot.socketManager.onPublish = { _, _ in
            publishScreenEventCalled = true
            expectation.fulfill()
        }

        // Generated refresh bypasses an earlier screen throttle, but retains its own ACK slot.
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10)

        // Assert (wait for the delayed call)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(publishScreenEventCalled)
    }

    func testPublishFakeReloadScreenEvent_bypassesPreviousThrottleAndSuppressesHostResumeScreen() {
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Test Screen")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
        let published = recordPublishedEvents()

        let sent = analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertTrue(sent)
        analyticsPublisher.testPublish(Event(type: .screen("Test Screen")))
        XCTAssertEqual(published(), [Constants.Event.screenEvent])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().count, 1)
    }

    func testExperiencePublished_shouldUpdateSeenExperiences() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.testPublish(screenEvent)

        // Act
        analyticsPublisher.experiencePublished(.flow, 123)

        // Assert
        XCTAssertTrue(analyticsPublisher.screenSessionStateMachine?.seenExperiences.contains(123) ?? false)
    }

    func testExperiencePublished_shouldUpdateSeenSurveys() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.testPublish(screenEvent)

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
        analyticsPublisher.testPublish(firstScreenEvent)
        let firstScreenSessionStateMachine = analyticsPublisher.screenSessionStateMachine
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        analyticsPublisher.testPublish(secondScreenEvent)
        let secondScreenSessionStateMachine = analyticsPublisher.screenSessionStateMachine

        // Assert
        XCTAssertNotEqual(firstScreenSessionStateMachine?.event.screenTitle, secondScreenSessionStateMachine?.event.screenTitle)
        XCTAssertEqual(secondScreenSessionStateMachine?.event.screenTitle, "Screen 2")
    }

    func testSetupScreenEvent_shouldRetainSeenExperiencesForSameScreen() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Same Screen"))
        analyticsPublisher.testPublish(screenEvent)
        analyticsPublisher.experiencePublished(.flow, 123)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        // Act
        analyticsPublisher.testPublish(screenEvent) // Same screen again

        // Assert
        XCTAssertTrue(analyticsPublisher.screenSessionStateMachine?.seenExperiences.contains(123) ?? false)
    }

    // MARK: - Session State Tests

    func testUpdateSessionState_shouldSetStartSessionTrueWhenSessionExpired() {
        // Arrange
        let pastDate = Date().addingTimeInterval(-35 * 60) // 35 minutes ago
        userpilot.storage.sessionDate = pastDate

        // Act
        analyticsPublisher.testResume()
        analyticsPublisher.mockWaitForQueue()

        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
        XCTAssertNil(userpilot.storage.sessionDate)
    }

    func testUpdateSessionState_shouldSetStartSessionFalseWhenSessionNotExpired() {
        // Arrange
        let recentDate = Date().addingTimeInterval(-10 * 60) // 10 minutes ago
        userpilot.storage.sessionDate = recentDate

        // Act
        analyticsPublisher.testResume()
        analyticsPublisher.mockWaitForQueue()

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
        analyticsPublisher.testPublish(eventWithoutUserId)

        // Assert
        XCTAssertFalse(connectCalled)
    }

    // MARK: - Autocapture screen guard (Android parity)

    /// An autocapture event with no screen is meaningless, so it must be neither sent nor STORED.
    /// The offline branch of `publish` returns before `trackEvent` runs, so the guard has to sit
    /// on that path too or the event is persisted and replayed later.
    func testPublish_autoCaptureWithoutScreen_isNotPersistedOffline() {
        userpilot.storage.userId = "user-1"
        userpilot.offlineEventsHandler.shouldSaveOffline = true

        analyticsPublisher.testPublish(makeAutoCaptureEvent(screen: nil))

        XCTAssertTrue(
            userpilot.offlineEventsHandler.savedEvents.isEmpty,
            "a screenless autocapture event must not reach local storage")
    }

    /// The autocapture pipeline can hand over an EMPTY screen dictionary, which carries no more
    /// information than a missing one.
    func testPublish_autoCaptureWithEmptyScreen_isNotPersistedOffline() {
        userpilot.storage.userId = "user-1"
        userpilot.offlineEventsHandler.shouldSaveOffline = true

        analyticsPublisher.testPublish(makeAutoCaptureEvent(screen: [:]))

        XCTAssertTrue(
            userpilot.offlineEventsHandler.savedEvents.isEmpty,
            "an empty screen map must be treated as no screen")
    }

    /// The guard must not swallow a well-formed autocapture event.
    func testPublish_autoCaptureWithScreen_isPersistedOffline() {
        userpilot.storage.userId = "user-1"
        userpilot.offlineEventsHandler.shouldSaveOffline = true

        analyticsPublisher.testPublish(makeAutoCaptureEvent())

        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.count, 1)
    }

    // MARK: - Track Event Throttle Key Tests

    private func makeAutoCaptureEvent(
        properties: Payload = nil,
        screen: Payload = [Constants.AutoCapture.screenClass: "HomeViewController"],
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
    ///
    /// The pipeline is ACK-gated: `processEvent` claims a single-flight gate and only releases it
    /// when the socket resolves the captured request's completion. The mock returns an ACK for
    /// each submission; the real publisher enqueues its progression on its owner queue.
    /// Without it only the first event is ever published and every later one stays queued,
    /// so any multi-event expectation fails on timeout, and any
    /// single-event expectation passes for the wrong reason (the gate caps it at one regardless of
    /// whether the throttle works).
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
        userpilot.socketManager.onPublishRequest = { request in
            publishCount += 1
            expectation.fulfill()
            request.completion?(Message(), true)
        }

        events.forEach { analyticsPublisher.publish($0) }

        wait(for: [expectation], timeout: timeout)
        // Each ACK enqueues progression; drain that work before counting unexpected extra sends.
        analyticsPublisher.testSettle()
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
                Constants.AutoCapture.hierarchy: hierarchy,
                Constants.AutoCapture.rawInteractionType: "view_presented",
                Constants.AutoCapture.dialogTitle: "Delete item?"
            ],
            interactionEventName: "view_presented"
        )
        let logoutDialog = makeAutoCaptureEvent(
            properties: [
                Constants.AutoCapture.hierarchy: hierarchy,
                Constants.AutoCapture.rawInteractionType: "view_presented",
                Constants.AutoCapture.dialogTitle: "Log out?"
            ],
            interactionEventName: "view_presented"
        )

        let publishCount = publishAndCountSocketPublishes([deleteDialog, logoutDialog], expectedCount: 2)

        XCTAssertEqual(publishCount, 2)
    }

    func testTrackEvent_autoCaptureUnresolvableScreenName_shouldStillUseOtherDiscriminators() {
        // Screen dict is non-empty (passes the flush guard) but has no
        // class/title/name, so the screen segment cannot be resolved
        let screen: Payload = [Constants.AutoCapture.screenType: "modal"]
        let saveTap = makeAutoCaptureEvent(
            properties: [Constants.AutoCapture.targetText: "Save"],
            screen: screen
        )
        let cancelTap = makeAutoCaptureEvent(
            properties: [Constants.AutoCapture.targetText: "Cancel"],
            screen: screen
        )

        let publishCount = publishAndCountSocketPublishes([saveTap, cancelTap], expectedCount: 2)

        XCTAssertEqual(publishCount, 2)
    }

    func testTrackEvent_autoCaptureIdenticalEvents_secondShouldThrottle() {
        let tap = makeAutoCaptureEvent(
            properties: [
                Constants.AutoCapture.hierarchy: "UIButton:attr__index=\"0\";HomeViewController",
                Constants.AutoCapture.rawInteractionType: "tap",
                Constants.AutoCapture.targetText: "Save"
            ]
        )

        let publishCount = publishAndCountSocketPublishes([tap, tap], expectedCount: 1)

        XCTAssertEqual(publishCount, 1)
    }

    func testTrackEvent_autoCaptureTabEvents_differentTabsShouldBothPublish() {
        let homeTab = makeAutoCaptureEvent(
            properties: [
                Constants.AutoCapture.tabName: "Home",
                Constants.AutoCapture.tabIndex: 0,
                Constants.AutoCapture.rawInteractionType: "tab_selected"
            ],
            interactionEventName: "tab_selected"
        )
        let profileTab = makeAutoCaptureEvent(
            properties: [
                Constants.AutoCapture.tabName: "Profile",
                Constants.AutoCapture.tabIndex: 1,
                Constants.AutoCapture.rawInteractionType: "tab_selected"
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

    // MARK: - User Switch With A Screen Tracked Right After Identify

    /// A user switch selects the new id immediately and retains its identify before closing the old
    /// socket. Any event queued behind that identify — a screen tracked right after `identify` —
    /// must survive teardown, otherwise the post-identify screen uses the previous title.
    func testUserSwitch_withQueuedScreen_shouldConsumeSessionStartOnScreenACK() {
        // Arrange: user N is identified and sitting on the "online queue" screen
        userpilot.storage.userId = "userN"
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        var screenPayloads: [Payload] = []
        userpilot.socketManager.onPublish = { eventName, payload in
            if eventName == Constants.Event.screenEvent { screenPayloads.append(payload) }
        }

        analyticsPublisher.testPublish(Event(type: .screen("online queue")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        // Arrange: the new user's identify and a screen right behind it are both queued while the
        // socket is joining (mirrors the asynchronous processing on device)
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.testPublish(Event(type: .identify("userA")))
        analyticsPublisher.testPublish(Event(type: .screen("queue s1 home")))
        userpilot.socketManager.isJoiningSocket = false

        // Act: admission already selected user A and retained the identify before teardown.
        // The close callback reconnects without dequeuing or republishing it.
        userpilot.socketManager.isSocketOpened = false
        analyticsPublisher.testOnSocketClosed()
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)

        // Assert: only the queued screen event follows the switch — no post-identify screen event —
        // and it carries its own title, starting a new session for the new user
        XCTAssertEqual(screenPayloads.count, 2)
        let payload = screenPayloads.last?.flatMap { $0 } ?? [:]
        XCTAssertEqual(payload[Constants.Analytics.screenTitleProperty] as? String, "queue s1 home")

        let metadata = payload[Constants.Analytics.metaDataProperty] as? [String: Any] ?? [:]
        XCTAssertEqual(metadata[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
        XCTAssertEqual(metadata[Constants.Analytics.fakeReload] as? Bool, false)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        // A screen ACK consumes session-start; same-screen refresh and identify continue the session.
        XCTAssertTrue(analyticsPublisher.publishFakeReloadScreenEvent(nil, nil, isFakeReload: true))
        analyticsPublisher.testSettle()
        var refreshMetadata = userpilot.socketManager.requests.last?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, false)
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.fakeReload] as? Bool, true)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        analyticsPublisher.testPublish(Event(type: .identify("userA")))
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)
        refreshMetadata = userpilot.socketManager.requests.last?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, false)
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.fakeReload] as? Bool, true)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        analyticsPublisher.testPublish(Event(type: .screen("Checkout")))
        let navigationMetadata = userpilot.socketManager.requests.last?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(navigationMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, false)
        XCTAssertEqual(navigationMetadata?[Constants.Analytics.fakeReload] as? Bool, false)
    }

    func testSameUserIdentify_afterLogoutAndScreenACK_shouldContinueSession() {
        assertSameUserIdentifyAfterScreenACK(afterLogout: true)
    }

    func testSameUserIdentify_afterUserSwitchAndScreenACK_shouldContinueSession() {
        assertSameUserIdentifyAfterScreenACK(afterLogout: false)
    }

    func testFailedScreenReply_shouldNotConsumeSessionStart() {
        userpilot.storage.userId = "same-user"
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("Home")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), false)
        XCTAssertTrue(analyticsPublisher.isStartSession)

        analyticsPublisher.testPublish(Event(type: .identify("same-user")))
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)
        let metadata = userpilot.socketManager.requests.last?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(metadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertFalse(analyticsPublisher.isStartSession)
    }

    private func assertSameUserIdentifyAfterScreenACK(afterLogout: Bool) {
        userpilot.storage.userId = "previous-user"
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testPublish(Event(type: .screen("online queue"), properties: ["screen_source": "manual"]))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        if afterLogout {
            analyticsPublisher.logout()
            userpilot.storage.userId = ""
        }
        let userId = afterLogout ? "previous-user" : "next-user"
        analyticsPublisher.testPublish(Event(type: .identify(userId), properties: ["source": "online_queue_setup"]))
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)

        let initialScreen = userpilot.socketManager.requests.last
        XCTAssertEqual(initialScreen?.event, Constants.Event.screenEvent)
        XCTAssertEqual(initialScreen?.payload?[Constants.Analytics.screenTitleProperty] as? String, "online queue")
        let initialMetadata = initialScreen?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(initialMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
        XCTAssertEqual(initialMetadata?[Constants.Analytics.fakeReload] as? Bool, false)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        // QA's second identify comes after the first screen's successful ACK, on the same screen.
        analyticsPublisher.testPublish(Event(type: .identify(userId), properties: ["source": "online_queue_setup"]))
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)
        let refresh = userpilot.socketManager.requests.last
        XCTAssertEqual(refresh?.event, Constants.Event.screenEvent)
        XCTAssertEqual(refresh?.payload?[Constants.Analytics.screenTitleProperty] as? String, "online queue")
        let refreshMetadata = refresh?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(refreshMetadata?["screen_source"] as? String, "manual")
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, false)
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.fakeReload] as? Bool, true)
    }

    func testLogout_shouldResetSessionStartForNextIdentityOnRetainedScreen() {
        userpilot.socketManager.isSocketOpened = true
        userpilot.storage.userId = "first-user"
        analyticsPublisher.testPublish(Event(type: .screen("Home")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        analyticsPublisher.testPublish(Event(type: .screen("Checkout")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertFalse(analyticsPublisher.isStartSession)

        analyticsPublisher.logout()
        userpilot.storage.userId = "" // Userpilot clears storage after the synchronous publisher logout.
        analyticsPublisher.testSettle()
        analyticsPublisher.testPublish(Event(type: .identify("next-user")))
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)

        let screenRequest = userpilot.socketManager.requests.last
        XCTAssertEqual(screenRequest?.event, Constants.Event.screenEvent)
        XCTAssertEqual(screenRequest?.payload?[Constants.Analytics.screenTitleProperty] as? String, "Checkout")
        let metadata = screenRequest?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(metadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
    }

    func testLogout_withSameUserAndQueuedScreen_shouldStartNewSession() {
        assertLogoutStartsSession(nextUserId: "first-user")
    }

    func testLogout_withDifferentUserAndQueuedScreen_shouldStartNewSession() {
        assertLogoutStartsSession(nextUserId: "next-user")
    }

    private func assertLogoutStartsSession(nextUserId: String) {
        userpilot.socketManager.isSocketOpened = true
        userpilot.storage.userId = "first-user"
        analyticsPublisher.testPublish(Event(type: .screen("Home")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        analyticsPublisher.testPublish(Event(type: .screen("Checkout")))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertFalse(analyticsPublisher.isStartSession)

        analyticsPublisher.logout()
        userpilot.storage.userId = "" // The facade clears identity after synchronous logout.
        analyticsPublisher.testPublish(Event(type: .identify(nextUserId)))
        analyticsPublisher.testPublish(Event(type: .screen("Login home")))
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)

        let request = userpilot.socketManager.requests.last
        XCTAssertEqual(request?.event, Constants.Event.screenEvent)
        XCTAssertEqual(request?.payload?[Constants.Analytics.screenTitleProperty] as? String, "Login home")
        let metadata = request?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(metadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
        XCTAssertEqual(metadata?[Constants.Analytics.fakeReload] as? Bool, false)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        XCTAssertTrue(analyticsPublisher.publishFakeReloadScreenEvent(nil, nil, isFakeReload: true))
        analyticsPublisher.testSettle()
        let refreshMetadata = userpilot.socketManager.requests.last?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(refreshMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, false)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        analyticsPublisher.testPublish(Event(type: .screen("Next screen")))
        let navigationMetadata = userpilot.socketManager.requests.last?.payload?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(navigationMetadata?[Constants.Analytics.isSessionStartedProperty] as? Bool, false)
    }

    // MARK: - Screen reloads and host identify

    /// Establishes an acknowledged screen session through the real FIFO before requesting a reload.
    private func arrangeReloadableScreen(
        title: String = "Reload Screen",
        userId: String = "reload-user"
    ) {
        userpilot.socketManager.isSocketOpened = true
        userpilot.storage.userId = userId

        analyticsPublisher.testPublish(Event(type: .screen(title)))
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        // Reset is the public lifecycle entry that clears throttle state; avoid real-time sleeps.
        analyticsPublisher.testReset()
    }

    /// Records the event names published to the socket from this point on.
    private func recordPublishedEvents() -> () -> [String] {
        var names = [String]()
        let lock = NSLock()
        userpilot.socketManager.onPublish = { name, _ in
            lock.lock()
            names.append(name)
            lock.unlock()
        }
        return {
            lock.lock()
            defer { lock.unlock() }
            return names
        }
    }

    func testReloadSendsTheScreenEventAlone() {
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertEqual(published(), [Constants.Event.screenEvent])
    }

    func testReloadACK_keepsTheNextScreenQueuedUntilItsOwnACK() {
        arrangeReloadableScreen(title: "Home")
        var titles: [String] = []
        userpilot.socketManager.onPublish = { name, payload in
            XCTAssertEqual(name, Constants.Event.screenEvent)
            titles.append(payload?[Constants.Analytics.screenTitleProperty] as? String ?? "")
        }

        XCTAssertTrue(analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true))
        analyticsPublisher.testPublish(Event(type: .screen("Checkout")))

        XCTAssertEqual(titles, ["Home"], "Navigation must wait for the reload ACK")
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.screenTitle), ["Home", "Checkout"])
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertEqual(titles, ["Home", "Checkout"])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.screenTitle), ["Checkout"])
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    func testPostIdentifyScreenACK_doesNotDiscardTheFollowingTrackEvent() {
        userpilot.storage.userId = "user-1"
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.updateScreen("Home")
        var sent: [(String, Payload)] = []
        userpilot.socketManager.onPublish = { sent.append(($0, $1)) }
        analyticsPublisher.testPublish(Event(type: .identify("user-1"), properties: ["plan": "pro"]))
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)
        XCTAssertEqual(sent.map { $0.0 }, [Constants.Event.identifyEvent, Constants.Event.screenEvent])

        analyticsPublisher.testPublish(Event(type: .event("Purchase"), properties: ["amount": 42]))
        XCTAssertEqual(sent.count, 2)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)

        XCTAssertEqual(sent.map { $0.0 }, [
            Constants.Event.identifyEvent, Constants.Event.screenEvent, Constants.Event.trackEvent
        ])
        XCTAssertEqual(sent.last?.1?[Constants.Analytics.eventNameProperty] as? String, "Purchase")
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().first?.eventTitle, "Purchase")
        acknowledge(Constants.Event.trackEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    func testFailedPush_dropsOnlyTheCurrentEventAndPublishesTheNext() {
        userpilot.storage.userId = "user-1"
        userpilot.socketManager.isSocketOpened = true
        var titles: [String] = []
        userpilot.socketManager.onPublish = { _, payload in
            titles.append(payload?[Constants.Analytics.eventNameProperty] as? String ?? "")
        }

        analyticsPublisher.testPublish(Event(type: .event("First")))
        analyticsPublisher.testPublish(Event(type: .event("Second")))
        XCTAssertEqual(titles, ["First"])

        acknowledge(Constants.Event.trackEvent, nil, Message(), false)

        XCTAssertEqual(titles, ["First", "Second"])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.eventTitle), ["Second"])
        acknowledge(Constants.Event.trackEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    func testBackgroundScreenRefresh_holdsTheQueueUntilItResolves() {
        arrangeReloadableScreen(title: "Home")
        userpilot.sessionMonitor.isAppActive = false
        analyticsPublisher.testFlush()
        userpilot.sessionMonitor.isAppActive = true
        var sent: [(String, Payload)] = []
        userpilot.socketManager.onPublish = { sent.append(($0, $1)) }

        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.testOnSocketOpened()
        analyticsPublisher.testPublish(Event(type: .screen("Checkout")))

        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.1?[Constants.Analytics.screenTitleProperty] as? String, "Home")
        let metadata = sent.first?.1?[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(metadata?[Constants.Analytics.fakeReload] as? Bool, false)
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.screenTitle), ["Home", "Checkout"])

        // A failed/timeout resolution must also release only the refresh's queue entry.
        acknowledge(Constants.Event.screenEvent, nil, Message(), false)
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent.last?.1?[Constants.Analytics.screenTitleProperty] as? String, "Checkout")
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.screenTitle), ["Checkout"])
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    func testReload_waitsForOfflineReplayBeforeSendingItsQueuedScreen() {
        arrangeReloadableScreen(title: "Home")
        userpilot.offlineEventsHandler.hasCachedEvents = true
        userpilot.offlineEventsHandler.holdRestoreCompletion = true
        let sent = recordPublishedEvents()

        let accepted = analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertTrue(accepted, "The refresh waits in the same queue during offline replay")
        XCTAssertEqual(sent(), [])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().map(\.screenTitle), ["Home"])
        analyticsPublisher.testPublish(Event(type: .event("Purchase")))
        userpilot.offlineEventsHandler.finishRestore()
        analyticsPublisher.testSettle()
        XCTAssertEqual(sent(), [Constants.Event.screenEvent])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().count, 2)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertEqual(sent(), [Constants.Event.screenEvent, Constants.Event.trackEvent])
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().first?.eventTitle, "Purchase")
        acknowledge(Constants.Event.trackEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    func testAppScreenEvent_publishesWithoutIdentify() {
        arrangeReloadableScreen()
        var published: [String] = []
        var screenTitle: String?
        userpilot.socketManager.onPublish = { name, payload in
            published.append(name)
            screenTitle = payload?[Constants.Analytics.screenTitleProperty] as? String
        }

        analyticsPublisher.testPublish(Event(type: .screen("Another Screen")))

        XCTAssertEqual(published, [Constants.Event.screenEvent])
        XCTAssertEqual(screenTitle, "Another Screen")
        XCTAssertEqual(analyticsPublisher.mockGetEventsToFlush().first?.screenTitle, "Another Screen")
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
    }

    func testReloadSendsOnlyScreen_whenCachedUserIsEmpty() {
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertEqual(published(), [Constants.Event.screenEvent])
    }

    func testReloadAfterPreviousReloadACK_isAdmittedWithoutWaitingForHostThrottle() {
        arrangeReloadableScreen()
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)
        acknowledge(Constants.Event.screenEvent, nil, Message(), true)
        XCTAssertTrue(analyticsPublisher.mockGetEventsToFlush().isEmpty)
        let published = recordPublishedEvents()

        let sent = analyticsPublisher.publishFakeReloadScreenEvent(.flow, 11, isFakeReload: true)

        XCTAssertTrue(sent)
        XCTAssertEqual(published(), [Constants.Event.screenEvent])
    }

    func testIdentifyCarryingNewDataIsForwarded() {
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.testPublish(
            Event(type: .identify("reload-user"), properties: ["plan": "enterprise"]))

        XCTAssertEqual(published(), [Constants.Event.identifyEvent])
    }

    func testIdentifyACKDoesNotResendPushToken() {
        arrangeReloadableScreen()
        let published = recordPublishedEvents()
        analyticsPublisher.testPublish(Event(type: .identify("reload-user"), properties: ["plan": "enterprise"]))
        acknowledge(Constants.Event.identifyEvent, nil, Message(), true)
        XCTAssertEqual(published(), [Constants.Event.identifyEvent, Constants.Event.screenEvent])
    }

    // MARK: - Internal SDK Events Ordering Around A Screen Message

    /// A `screen` message makes the backend re-evaluate content for the surface, so a cached
    /// dismissal has to be on the wire first — otherwise the fake reload the dismissal itself
    /// triggered gets the dismissed content served straight back.
    ///
    /// The cause reproduced here is the one that does not depend on dispatch: the event is cached
    /// while the socket is down, so nothing drains it, and the reload then pushes the screen from
    /// `publishScreenEvent`. On device the same gap opens whenever `processEvent`'s single-flight
    /// gate is already claimed (e.g. an asynchronous offline restore) and the drain it schedules
    /// never runs.
    func testFakeReload_shouldPushCachedSDKEventsBeforeTheScreenEvent() {
        // Arrange — a live screen session, and a content dismissal cached while the socket was down
        arrangeReloadableScreen()
        userpilot.socketManager.isSocketOpened = false
        analyticsPublisher.testPublishInternalSDKEvent(
            MockSDKEvent(eventName: "dismissed_mobile_content"))
        userpilot.socketManager.isSocketOpened = true
        let published = recordPublishedEvents()

        // Act — the dismissal drives a fake reload for the current screen
        XCTAssertTrue(analyticsPublisher.publishFakeReloadScreenEvent(.flow, 2, isFakeReload: true))

        // Assert — the dismissal reaches the socket before the screen message
        XCTAssertEqual(published(), ["dismissed_mobile_content", Constants.Event.screenEvent])
    }

    // MARK: - Internal SDK Events Offline Gate

    // The three tests below assert synchronously on purpose. `publishInternalSDKEvent`
    // (`Sources/Userpilot/Analytics/AnalyticsPublisher.swift:1202`) runs its whole body on the
    // calling thread: `tryCatch` (`Sources/Userpilot/Utilities/Helper/Utils.swift:149`) is a plain
    // non-escaping `try?` wrapper, and the gate sits ahead of every dispatch in the method, so the
    // mock has already been touched by the time the call returns.
    //
    // Each one also pins the *other* branch — whether `openSocket()` ran — so the `isEmpty`
    // assertions cannot pass by the event having been dropped on the floor.

    func testPublishInternalSDKEvent_persistsAnEligibleEventWhileOffline() throws {
        let offlineHandler = try XCTUnwrap(
            userpilot.container.resolve(OfflineEventsHandling.self) as? MockOfflineEventsHandler)
        offlineHandler.shouldSaveOffline = true
        var didOpenSocket = false
        userpilot.socketManager.onConnect = { didOpenSocket = true }
        let sdkEvent = MockSDKEvent(
            eventName: "seen_mobile_content_step",
            eventPayload: ["mobile_content_id": 42]
        )

        analyticsPublisher.testPublishInternalSDKEvent(sdkEvent)

        XCTAssertEqual(offlineHandler.savedSDKEvents.count, 1)
        XCTAssertEqual(offlineHandler.savedSDKEvents.first?.eventName, "seen_mobile_content_step")
        // The early return is load-bearing beyond the persist: reopening the socket cannot
        // succeed with no network.
        XCTAssertFalse(didOpenSocket)
    }

    func testPublishInternalSDKEvent_keepsTheInMemoryPathForAnIneligibleEventWhileOffline() throws {
        let offlineHandler = try XCTUnwrap(
            userpilot.container.resolve(OfflineEventsHandling.self) as? MockOfflineEventsHandler)
        offlineHandler.shouldSaveOffline = true
        var didOpenSocket = false
        userpilot.socketManager.onConnect = { didOpenSocket = true }

        analyticsPublisher.testPublishInternalSDKEvent(MockSDKEvent(eventName: "get_mobile_content"))

        XCTAssertTrue(offlineHandler.savedSDKEvents.isEmpty)
        // Neither persisted nor dropped: a request/response event still takes the cached route
        // and still asks for a socket, so it retries live on reconnect.
        XCTAssertTrue(didOpenSocket)
    }

    func testPublishInternalSDKEvent_doesNotPersistWhenTheNetworkIsAvailable() throws {
        let offlineHandler = try XCTUnwrap(
            userpilot.container.resolve(OfflineEventsHandling.self) as? MockOfflineEventsHandler)
        offlineHandler.shouldSaveOffline = false
        var didOpenSocket = false
        userpilot.socketManager.onConnect = { didOpenSocket = true }

        analyticsPublisher.testPublishInternalSDKEvent(
            MockSDKEvent(eventName: "seen_mobile_content_step", eventPayload: ["mobile_content_id": 42]))

        XCTAssertTrue(offlineHandler.savedSDKEvents.isEmpty)
        XCTAssertTrue(didOpenSocket)
    }
}

// swiftlint:enable all
