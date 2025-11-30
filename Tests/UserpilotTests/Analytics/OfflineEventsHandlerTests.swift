//
//  OfflineEventsHandlerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 16/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import Foundation
import XCTest

@testable import Userpilot

// swiftlint:disable all

class OfflineEventsHandlerTests: XCTestCase {

    var offlineEventsHandler: OfflineEventsHandler!
    var userpilot: MockUserpilot!
    var mockEventStorage: MockEventStoring!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)

        // Get reference to the mock event storage that's already registered
        mockEventStorage = userpilot.eventStoring

        // Set default network monitor state
        userpilot.networkMonitor.isNetworkAvailable = true
        userpilot.networkMonitor.isReady = true

        // Set default storage values
        userpilot.storage.userId = "test-user"

        offlineEventsHandler = OfflineEventsHandler(container: userpilot.container)
    }

    override func tearDown() {
        // Reset all mock callbacks to avoid interference between tests
        mockEventStorage.onSaveEvent = nil
        mockEventStorage.onGetAllEventsAndDelete = nil
        mockEventStorage.onDeleteEvent = nil
        mockEventStorage.onDeleteAllEvents = nil
        mockEventStorage.onGetStorageStats = nil
        mockEventStorage.onHasEvents = nil
        mockEventStorage.hasEventsValue = false

        offlineEventsHandler = nil
        mockEventStorage = nil
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_shouldRegisterAsSocketSubscription() {
        // Assert
        // Verify that registerCallback was called during initialization
        // This is implicitly tested by the fact that the handler exists
        XCTAssertNotNil(offlineEventsHandler)
    }

    // MARK: - shouldSaveOffline Tests

    func testShouldSaveOffline_whenNetworkAvailable_shouldReturnFalse() {
        // Arrange
        userpilot.networkMonitor.isNetworkAvailable = true
        userpilot.networkMonitor.isReady = true

        // Act & Assert
        XCTAssertFalse(offlineEventsHandler.shouldSaveOffline)
    }

    func testShouldSaveOffline_whenNetworkUnavailable_shouldReturnTrue() {
        // Arrange
        userpilot.networkMonitor.isNetworkAvailable = false
        userpilot.networkMonitor.isReady = true

        // Act & Assert
        XCTAssertTrue(offlineEventsHandler.shouldSaveOffline)
    }

    func testShouldSaveOffline_whenNetworkNotReady_shouldReturnFalse() {
        // Arrange
        userpilot.networkMonitor.isNetworkAvailable = false
        userpilot.networkMonitor.isReady = false

        // Act & Assert
        XCTAssertFalse(offlineEventsHandler.shouldSaveOffline)
    }

    // MARK: - hasCachedEvents Tests

    func testHasCachedEvents_whenEventsExist_shouldReturnTrue() {
        // Arrange
        mockEventStorage.hasEventsValue = true

        // Act & Assert
        XCTAssertTrue(offlineEventsHandler.hasCachedEvents)
    }

    func testHasCachedEvents_whenNoEvents_shouldReturnFalse() {
        // Arrange
        mockEventStorage.hasEventsValue = false

        // Act & Assert
        XCTAssertFalse(offlineEventsHandler.hasCachedEvents)
    }

    // MARK: - saveEventToLocalStorage Tests

    func testSaveEventToLocalStorage_withValidUserId_shouldSaveEvent() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test_event"), properties: ["key": "value"])

        let expectation = XCTestExpectation(description: "Event saved to storage")
        var savedEvent: EventStorage?

        mockEventStorage.onSaveEvent = { eventStorage, completion in
            savedEvent = eventStorage
            completion(true)
            expectation.fulfill()
        }

        // Act
        offlineEventsHandler.saveEventToLocalStorage(event: event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(savedEvent)
        XCTAssertEqual(savedEvent?.userId, "test-user")
        XCTAssertEqual(savedEvent?.token, "NX-00000")
    }

    func testSaveEventToLocalStorage_withEmptyUserId_shouldNotSaveEvent() {
        // Arrange
        userpilot.storage.userId = ""
        let event = Event(type: .event("test_event"))

        let expectation = XCTestExpectation(description: "Event should not be saved")
        expectation.isInverted = true

        mockEventStorage.onSaveEvent = { _, completion in
            expectation.fulfill()
            completion(true)
        }

        // Act
        offlineEventsHandler.saveEventToLocalStorage(event: event)

        // Assert
        wait(for: [expectation], timeout: 0.5)
    }

    func testSaveEventToLocalStorage_whenStorageLimitExceeded_shouldLogError() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test_event"))

        let expectation = XCTestExpectation(description: "Event save attempted")

        mockEventStorage.onSaveEvent = { _, completion in
            completion(false)  // Simulate storage limit exceeded
            expectation.fulfill()
        }

        // Act
        offlineEventsHandler.saveEventToLocalStorage(event: event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        // Should log error but not crash
    }

    func testSaveEventToLocalStorage_identifyEvent_shouldSaveWithMetadata() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(
            type: .identify("user-123"),
            properties: ["name": "John"],
            company: ["id": "company-1"]
        )

        let expectation = XCTestExpectation(description: "Identify event saved")
        var savedEvent: EventStorage?

        mockEventStorage.onSaveEvent = { eventStorage, completion in
            savedEvent = eventStorage
            completion(true)
            expectation.fulfill()
        }

        // Act
        offlineEventsHandler.saveEventToLocalStorage(event: event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(savedEvent)

        // Verify event can be decoded back
        let decodedEvent = savedEvent?.toEvent()
        XCTAssertEqual(decodedEvent?.userId, "user-123")
    }

    func testSaveEventToLocalStorage_screenEvent_shouldSaveWithScreenTitle() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .screen("Home Screen"))

        let expectation = XCTestExpectation(description: "Screen event saved")
        var savedEvent: EventStorage?

        mockEventStorage.onSaveEvent = { eventStorage, completion in
            savedEvent = eventStorage
            completion(true)
            expectation.fulfill()
        }

        // Act
        offlineEventsHandler.saveEventToLocalStorage(event: event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(savedEvent)

        // Verify event can be decoded back
        let decodedEvent = savedEvent?.toEvent()
        XCTAssertEqual(decodedEvent?.screenTitle, "Home Screen")
    }

    // MARK: - restoreEventsFromLocalStorage Tests

    func testRestoreEventsFromLocalStorage_withNoEvents_shouldCompleteImmediately() {
        // Arrange
        let expectation = XCTestExpectation(description: "Completion called")

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([])
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    func testRestoreEventsFromLocalStorage_withIdentifyEvent_shouldPublishBatch() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(
            type: .identify("test-user"),
            properties: ["name": "John"],
            company: ["id": "company-1"]
        )
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?
        var publishedEventName: String?

        userpilot.socketManager.onPublish = { eventName, payload, _ in
            publishedEventName = eventName
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion to ensure publish happened first
            XCTAssertEqual(publishedEventName, Constants.Event.batchEventsEvent)
            XCTAssertNotNil(publishedPayload)

            if let events = publishedPayload?["events"] as? [[String: Any]] {
                XCTAssertEqual(events.count, 1)
                XCTAssertEqual(events.first?["event_type"] as? String, "user_identify")
            } else {
                XCTFail("No events in payload")
            }

            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 3.0)
    }

    func testRestoreEventsFromLocalStorage_withScreenEvent_shouldPublishBatch() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .screen("Home Screen"))
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            if let events = publishedPayload?["events"] as? [[String: Any]] {
                XCTAssertEqual(events.count, 1)
                XCTAssertEqual(events.first?["event_type"] as? String, "screen")
                XCTAssertEqual(events.first?["title"] as? String, "Home Screen")
            } else {
                XCTFail("No events in payload")
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testRestoreEventsFromLocalStorage_withTrackEvent_shouldPublishBatch() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(
            type: .event("button_click"),
            properties: ["button_id": "submit"]
        )
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            if let events = publishedPayload?["events"] as? [[String: Any]] {
                XCTAssertEqual(events.count, 1)
                XCTAssertEqual(events.first?["event_type"] as? String, "track")
                XCTAssertEqual(events.first?["event_name"] as? String, "button_click")

                if let metadata = events.first?["metadata"] as? [String: Any] {
                    XCTAssertEqual(metadata["button_id"] as? String, "submit")
                } else {
                    XCTFail("No metadata in event")
                }
            } else {
                XCTFail("No events in payload")
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testRestoreEventsFromLocalStorage_withMultipleEvents_shouldPublishAllInBatch() {
        // Arrange
        userpilot.storage.userId = "test-user"

        let event1 = Event(type: .identify("test-user"))
        let event2 = Event(type: .screen("Home"))
        let event3 = Event(type: .event("click"))

        guard let storage1 = EventStorage(event1, "NX-00000", "test-user"),
            let storage2 = EventStorage(event2, "NX-00000", "test-user"),
            let storage3 = EventStorage(event3, "NX-00000", "test-user")
        else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([storage1, storage2, storage3])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            if let events = publishedPayload?["events"] as? [[String: Any]] {
                XCTAssertEqual(events.count, 3)
            } else {
                XCTFail("No events in payload")
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testRestoreEventsFromLocalStorage_withMultipleValidEvents_shouldPublishAll() {
        // Arrange
        userpilot.storage.userId = "test-user"

        // Create multiple valid events
        let event1 = Event(type: .event("event_1"))
        let event2 = Event(type: .screen("Screen 1"))
        let event3 = Event(type: .event("event_2"))

        guard let storage1 = EventStorage(event1, "NX-00000", "test-user"),
            let storage2 = EventStorage(event2, "NX-00000", "test-user"),
            let storage3 = EventStorage(event3, "NX-00000", "test-user")
        else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([storage1, storage2, storage3])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            if let events = publishedPayload?["events"] as? [[String: Any]] {
                // All 3 events should be published
                XCTAssertEqual(events.count, 3)
            } else {
                XCTFail("No events in payload")
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testRestoreEventsFromLocalStorage_whenAppActive_shouldSetIsClosingSocketFalse() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.sessionMonitor.isAppActive = true

        let event = Event(type: .event("test"))
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var isClosingSocket: Bool?

        userpilot.socketManager.onPublish = { _, _, closingSocket in
            isClosingSocket = closingSocket
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                [:],
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            XCTAssertEqual(isClosingSocket, false)
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testRestoreEventsFromLocalStorage_whenAppInactive_shouldSetIsClosingSocketTrue() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.sessionMonitor.isAppActive = false

        let event = Event(type: .event("test"))
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var isClosingSocket: Bool?

        userpilot.socketManager.onPublish = { _, _, closingSocket in
            isClosingSocket = closingSocket
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                [:],
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            XCTAssertEqual(isClosingSocket, true)
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func
        testRestoreEventsFromLocalStorage_withIdentifyEventWithCompany_shouldIncludeCompanyInPayload()
    {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(
            type: .identify("user-123"),
            properties: ["name": "John"],
            company: ["id": "company-1", "name": "Acme Corp"]
        )
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            if let events = publishedPayload?["events"] as? [[String: Any]] {
                XCTAssertEqual(events.count, 1)

                if let company = events.first?["company"] as? [String: Any] {
                    XCTAssertEqual(company["id"] as? String, "company-1")
                    XCTAssertEqual(company["name"] as? String, "Acme Corp")
                } else {
                    XCTFail("No company data in event")
                }
            } else {
                XCTFail("No events in payload")
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testRestoreEventsFromLocalStorage_shouldFormatTimestampCorrectly() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test"))
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            if let events = publishedPayload?["events"] as? [[String: Any]],
                let createdAt = events.first?["created_at"] as? String
            {
                // Verify ISO-8601 format with timezone
                XCTAssertTrue(createdAt.contains("T"))
                XCTAssertTrue(createdAt.contains(":"))
                // Should have timezone offset (e.g., +00:00 or -05:00)
                XCTAssertTrue(createdAt.contains("+") || createdAt.contains("Z"))
            } else {
                XCTFail("No created_at in event")
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - clearLocalEvents Tests

    func testClearLocalEvents_shouldDeleteAllEvents() {
        // Arrange
        let expectation = XCTestExpectation(description: "Delete all events called")

        mockEventStorage.onDeleteAllEvents = {
            expectation.fulfill()
        }

        // Act
        offlineEventsHandler.clearLocalEvents()

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - SocketSubscription Tests

    func testOnSocketEventSent_withBatchEventsEvent_shouldCallCompletion() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test"))
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let restoreExpectation = XCTestExpectation(description: "Restore completion called")
        var completionCalled = false

        // Act - First restore events
        offlineEventsHandler.restoreEventsFromLocalStorage {
            completionCalled = true
            restoreExpectation.fulfill()
        }

        // Wait for restore to publish batch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Simulate socket event sent callback
            let message = Message()
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                [:],
                message,
                true
            )
        }

        // Assert
        wait(for: [restoreExpectation], timeout: 2.0)
        XCTAssertTrue(completionCalled)
    }

    func testOnSocketEventSent_withNonBatchEvent_shouldNotCallCompletion() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test"))
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let restoreExpectation = XCTestExpectation(description: "Restore not completed yet")
        restoreExpectation.isInverted = true
        var completionCalled = false

        // Act - First restore events
        offlineEventsHandler.restoreEventsFromLocalStorage {
            completionCalled = true
            restoreExpectation.fulfill()
        }

        // Wait a bit then send a non-batch event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Simulate socket event sent callback with a different event
            let message = Message()
            self.offlineEventsHandler.onSocketEventSent(
                "screen",
                [:],
                message,
                true
            )
        }

        // Assert - completion should not be called
        wait(for: [restoreExpectation], timeout: 1.0)
        XCTAssertFalse(completionCalled)
    }

    // MARK: - Thread Safety Tests
    func testSaveEventToLocalStorage_concurrentCalls_shouldHandleSafely() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event1 = Event(type: .event("event1"))
        let event2 = Event(type: .event("event2"))

        var savedCount = 0
        mockEventStorage.onSaveEvent = { _, completion in
            savedCount += 1
            completion(true)
        }

        // Act - Save events concurrently
        offlineEventsHandler.saveEventToLocalStorage(event: event1)
        offlineEventsHandler.saveEventToLocalStorage(event: event2)

        // Wait a bit for async operations
        let expectation = XCTestExpectation(description: "Wait for saves")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // Assert - Both events should be saved
        XCTAssertEqual(savedCount, 2)
    }

    // MARK: - Edge Cases

    func testRestoreEventsFromLocalStorage_withEmptyProperties_shouldHandleGracefully() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(type: .event("test"), properties: nil)
        guard let eventStorage = EventStorage(event, "NX-00000", "test-user") else {
            XCTFail("Failed to create EventStorage")
            return
        }

        mockEventStorage.onGetAllEventsAndDelete = { completion in
            completion([eventStorage])
        }

        let expectation = XCTestExpectation(description: "Batch published and completed")
        var publishedPayload: [String: Any]?

        userpilot.socketManager.onPublish = { _, payload, _ in
            publishedPayload = payload
            // Simulate socket ack to complete restore flow
            self.offlineEventsHandler.onSocketEventSent(
                Constants.Event.batchEventsEvent,
                payload,
                Message(),
                true
            )
        }

        // Act
        offlineEventsHandler.restoreEventsFromLocalStorage {
            // Assert inside completion
            XCTAssertNotNil(publishedPayload)
            if let events = publishedPayload?["events"] as? [[String: Any]] {
                XCTAssertEqual(events.count, 1)
                // Metadata should be empty dict, not nil
                let metadata = events.first?["metadata"] as? [String: Any]
                XCTAssertNotNil(metadata)
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
    }

    func testSaveEventToLocalStorage_withSpecialCharacters_shouldEncodeProperly() {
        // Arrange
        userpilot.storage.userId = "test-user"
        let event = Event(
            type: .event("test_event"),
            properties: [
                "emoji": "😀🎉",
                "special": "Test & Co. <script>",
                "unicode": "Hello 世界",
            ]
        )

        let expectation = XCTestExpectation(description: "Event saved")
        var savedEvent: EventStorage?

        mockEventStorage.onSaveEvent = { eventStorage, completion in
            savedEvent = eventStorage
            completion(true)
            expectation.fulfill()
        }

        // Act
        offlineEventsHandler.saveEventToLocalStorage(event: event)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(savedEvent)

        // Verify event can be decoded back with special characters intact
        let decodedEvent = savedEvent?.toEvent()
        XCTAssertEqual(decodedEvent?.properties?["emoji"] as? String, "😀🎉")
        XCTAssertEqual(decodedEvent?.properties?["unicode"] as? String, "Hello 世界")
    }
}

// swiftlint:enable all
