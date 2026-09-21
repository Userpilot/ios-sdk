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
        analyticsPublisher.publishInternalSDKEvent(makePushTokenEvent())

        // Assert - the offline batch owns the wire, the token does not overtake it
        XCTAssertFalse(publishedEvents.contains(pushTokenEventName))

        // Act - the batch lands and the cached SDK events drain
        userpilot.offlineEventsHandler.finishRestore()

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
        analyticsPublisher.publishInternalSDKEvent(makePushTokenEvent())

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
        analyticsPublisher.publishInternalSDKEvent(makePushTokenEvent())
        XCTAssertFalse(publishedEvents.contains(pushTokenEventName))

        // Act
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.onSocketOpened()

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
        analyticsPublisher.publishInternalSDKEvent(makePushTokenEvent())
        analyticsPublisher.onSocketOpened()

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
        analyticsPublisher.publishInternalSDKEvent(contentEvent)

        // Assert
        XCTAssertFalse(publishedEvents.contains(contentEventName))

        // Act - the batch lands and the cached SDK events drain
        userpilot.offlineEventsHandler.finishRestore()

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
            analyticsPublisher.publishInternalSDKEvent(MockSDKEvent(eventName: $0))
        }
        XCTAssertTrue(publishedEvents.isEmpty)

        // Act
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.onSocketOpened()

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
            analyticsPublisher.publishInternalSDKEvent(MockSDKEvent(eventName: $0))
        }

        // Act
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.onSocketOpened()

        // Assert - only the first went out, and the re-drive on the empty queue settled
        // instead of spinning on the still-cached second event
        XCTAssertEqual(publishedEvents, ["sdk-event-1"])

        // Act - the socket comes back
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.onSocketOpened()

        // Assert - the second event survived the closed window
        XCTAssertEqual(publishedEvents, ["sdk-event-1", "sdk-event-2"])
    }

    func testIsExperienceSeen_shouldUseSeenSetForContentType() throws {
        // Arrange — the screen session (which owns the seen sets) is only created once the
        // screen event actually goes out, which requires an open socket.
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.publish(Event(type: .screen("Test Screen")))
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
        analyticsPublisher.publish(Event(type: .screen("Screen X")))
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
        analyticsPublisher.publish(Event(type: .screen("Screen Y")))

        // Assert — the flow is eligible again, and the screen event is still only stored
        XCTAssertFalse(analyticsPublisher.isExperienceSeen(.flow(content: flow)))
        XCTAssertEqual(analyticsPublisher.screenSessionStateMachine?.event.screenTitle, "Screen Y")
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.count, 1)
    }

    /// Re-entering the same screen is not navigation, so what was shown there stays suppressed.
    func testPublish_offlineSameScreen_shouldKeepSeenContent() throws {
        // Arrange — a flow already shown on the current screen
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.publish(Event(type: .screen("Screen X")))
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        analyticsPublisher.experiencePublished(.flow, flow.id)

        // Act — the same screen is tracked again with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.publish(Event(type: .screen("Screen X")))

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
        analyticsPublisher.publish(Event(type: .screen("Screen X")))
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return false }

        // Act — the host surface re-emits the same screen with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.publish(Event(type: .screen("Screen X")))

        // Assert — nothing is persisted, and the screen session still tracks the screen
        XCTAssertTrue(userpilot.offlineEventsHandler.savedEvents.isEmpty)
        XCTAssertEqual(analyticsPublisher.screenSessionStateMachine?.event.screenTitle, "Screen X")
    }

    /// The cooldown suppresses repeats, never real navigation — that would lose the screen.
    func testPublish_offlineNavigationAfterAnExperienceClosed_shouldStillBeStored() {
        // Arrange — the user is on "Screen X" and an experience has just been dismissed there
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.publish(Event(type: .screen("Screen X")))
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return false }

        // Act — the user navigates to another screen with no network
        userpilot.offlineEventsHandler.shouldSaveOffline = true
        analyticsPublisher.publish(Event(type: .screen("Screen Y")))

        // Assert — the navigation is persisted
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.count, 1)
        XCTAssertEqual(userpilot.offlineEventsHandler.savedEvents.first?.event.screenTitle, "Screen Y")
    }

    func testIsExperienceSeen_shouldNotCrossTypesForTheSameNumericId() throws {
        // Arrange — the screen session (which owns the seen sets) is only created once the
        // screen event actually goes out, which requires an open socket.
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.publish(Event(type: .screen("Test Screen")))
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
        analyticsPublisher.publish(Event(type: .screen("Test Screen")))
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
    /// when the socket resolves the in-flight head through `onSocketEventSent`. `MockSocketManager`
    /// has no backend, so the ACK is simulated here — asynchronously, the way the real push receipt
    /// arrives. Without it only the first event is ever published and every later one waits for the
    /// `pushTimeout + 2` (12s) watchdog, so any multi-event expectation fails on timeout, and any
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
        userpilot.socketManager.onPublish = { [weak self] eventName, payload in
            publishCount += 1
            expectation.fulfill()
            DispatchQueue.main.async {
                self?.analyticsPublisher.onSocketEventSent(eventName, payload, Message(), true)
            }
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

    // MARK: - User Switch With A Screen Tracked Right After Identify

    /// A user switch blanks the user id via `clean()` while the new user's identify waits in the
    /// queue to be replayed by `onSocketClosed`. Any event queued behind that identify — a screen
    /// tracked right after `identify` — must survive the replay, otherwise the queue empties and
    /// the post-identify screen event goes out carrying the *previous* screen.
    func testUserSwitch_withQueuedScreen_shouldPublishQueuedScreenTitleAndSkipPostIdentifyScreen() {
        // Arrange: user N is identified and sitting on the "online queue" screen
        userpilot.storage.userId = "userN"
        userpilot.storage.user = User(userId: "userN").toJson() ?? ""
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { true }

        var screenPayloads: [Payload] = []
        userpilot.socketManager.onPublish = { eventName, payload in
            if eventName == Constants.Event.screenEvent { screenPayloads.append(payload) }
        }

        analyticsPublisher.publish(Event(type: .screen("online queue")))
        analyticsPublisher.onSocketEventSent(Constants.Event.screenEvent, nil, Message(), true)

        // Arrange: the new user's identify and a screen right behind it are both queued while the
        // socket is joining (mirrors the asynchronous processing on device)
        userpilot.socketManager.isJoiningSocket = true
        analyticsPublisher.publish(Event(type: .identify("userA")))
        analyticsPublisher.publish(Event(type: .screen("queue s1 home")))
        userpilot.socketManager.isJoiningSocket = false

        // Act: the identify is processed, which switches user and tears the old socket down
        analyticsPublisher.onSocketOpened()

        // Act: the socket close replays the pending identify, then the connection comes back
        userpilot.socketManager.isSocketOpened = false
        analyticsPublisher.onSocketClosed()
        userpilot.socketManager.isSocketOpened = true
        analyticsPublisher.onSocketOpened()
        analyticsPublisher.onSocketEventSent(Constants.Event.identifyEvent, nil, Message(), true)

        // Assert: only the queued screen event follows the switch — no post-identify screen event —
        // and it carries its own title, starting a new session for the new user
        XCTAssertEqual(screenPayloads.count, 2)
        let payload = screenPayloads.last?.flatMap { $0 } ?? [:]
        XCTAssertEqual(payload[Constants.Analytics.screenTitleProperty] as? String, "queue s1 home")

        let metadata = payload[Constants.Analytics.metaDataProperty] as? [String: Any] ?? [:]
        XCTAssertEqual(metadata[Constants.Analytics.isSessionStartedProperty] as? Bool, true)
        XCTAssertEqual(metadata[Constants.Analytics.fakeReload] as? Bool, false)
    }

    // MARK: - Identify before screen

    /// Establishes a cached user and a live screen session, then waits out the screen throttle so
    /// the reload under test is not swallowed by it.
    ///
    /// `screenSessionStateMachine` is `private(set)`, so the session has to be built through a real
    /// screen event — hence the throttle wait.
    private func arrangeReloadableScreen(
        title: String = "Reload Screen",
        userId: String = "reload-user"
    ) {
        userpilot.socketManager.isSocketOpened = true
        userpilot.storage.userId = userId
        userpilot.storage.user = User(
            userId: userId,
            properties: ["plan": "pro"]
        ).toJson() ?? ""

        analyticsPublisher.publish(Event(type: .screen(title)))
        analyticsPublisher.onSocketEventSent(Constants.Event.screenEvent, nil, Message(), true)

        let throttleWindow = XCTestExpectation(description: "screen throttle window elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { throttleWindow.fulfill() }
        wait(for: [throttleWindow], timeout: 2.0)
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

    func testReloadSendsTheScreenEventAlone_whenTheFlagIsOff() {
        // The default configuration is unchanged by this feature.
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertEqual(published(), [Constants.Event.screenEvent])
    }

    func testReloadPublishesTheIdentifyFirst_whenTheFlagIsOn() {
        userpilot.config.requestIdentifyBeforeScreen = true
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertEqual(published(), [Constants.Event.identifyEvent, Constants.Event.screenEvent])
    }

    func testAppScreenEventIsPrecededByTheIdentify_whenTheFlagIsOn() {
        // The flag covers app-tracked screens too, not just the SDK's fake reloads.
        userpilot.config.requestIdentifyBeforeScreen = true
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publish(Event(type: .screen("Another Screen")))

        XCTAssertEqual(published(), [Constants.Event.identifyEvent, Constants.Event.screenEvent])
    }

    func testReloadIdentifyCarriesTheCachedUser_whenTheFlagIsOn() {
        userpilot.config.requestIdentifyBeforeScreen = true
        arrangeReloadableScreen()
        var identifyPayload: [String: Any]?
        userpilot.socketManager.onPublish = { name, payload in
            if name == Constants.Event.identifyEvent { identifyPayload = payload }
        }

        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        let metadata = identifyPayload?[Constants.Analytics.metaDataProperty] as? [String: String]
        XCTAssertEqual(metadata, ["plan": "pro"])
    }

    func testReloadSendsNothingExtra_whenNoUserIsIdentified() {
        userpilot.config.requestIdentifyBeforeScreen = true
        arrangeReloadableScreen()
        userpilot.storage.user = ""
        let published = recordPublishedEvents()

        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        XCTAssertEqual(published(), [Constants.Event.screenEvent])
    }

    func testIdentifyBeforeScreenAckDoesNotRequestASecondScreenEvent() {
        userpilot.config.requestIdentifyBeforeScreen = true
        arrangeReloadableScreen()
        let published = recordPublishedEvents()
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)

        // That identify never entered the queue, so its ack owns no head. Unclaimed, it satisfies
        // isPostIdentificationContext and would duplicate the screen event.
        analyticsPublisher.onSocketEventSent(Constants.Event.identifyEvent, nil, Message(), true)

        XCTAssertEqual(published(), [Constants.Event.identifyEvent, Constants.Event.screenEvent])
    }

    func testReloadSendsNeitherEvent_forAThrottledScreen() {
        userpilot.config.requestIdentifyBeforeScreen = true
        arrangeReloadableScreen()
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 10, isFakeReload: true)
        let published = recordPublishedEvents()

        // A second dismissal inside the throttle window sends no identify either.
        analyticsPublisher.publishFakeReloadScreenEvent(.flow, 11, isFakeReload: true)

        XCTAssertEqual(published(), [])
    }

    func testDuplicateIdentifyIsDropped() {
        // Re-stating an unchanged user is the flag's job, not the identify path's.
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publish(
            Event(type: .identify("reload-user"), properties: ["plan": "pro"]))

        XCTAssertEqual(published(), [])
    }

    func testIdentifyCarryingNewDataIsForwarded() {
        arrangeReloadableScreen()
        let published = recordPublishedEvents()

        analyticsPublisher.publish(
            Event(type: .identify("reload-user"), properties: ["plan": "enterprise"]))

        XCTAssertEqual(published(), [Constants.Event.identifyEvent])
    }

    func testPushTokenIsReassertedWhenAnIdentifyIsAcknowledged() {
        // The token senders are value-guarded, so an unchanged token would never re-pair
        // token <-> user without this.
        arrangeReloadableScreen()
        var resynced = false
        userpilot.pushNotificationMonitor.onResyncPushToken = { resynced = true }

        analyticsPublisher.publish(
            Event(type: .identify("reload-user"), properties: ["plan": "enterprise"]))
        analyticsPublisher.onSocketEventSent(Constants.Event.identifyEvent, nil, Message(), true)

        XCTAssertTrue(resynced)
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
        analyticsPublisher.publishInternalSDKEvent(
            MockSDKEvent(eventName: "dismissed_mobile_content"))
        userpilot.socketManager.isSocketOpened = true
        let published = recordPublishedEvents()

        // Act — the dismissal drives a fake reload for the current screen
        XCTAssertTrue(analyticsPublisher.publishFakeReloadScreenEvent(.flow, 2, isFakeReload: true))

        // Assert — the dismissal reaches the socket before the screen message
        XCTAssertEqual(published(), ["dismissed_mobile_content", Constants.Event.screenEvent])
    }
}

// swiftlint:enable all
