//
//  EventDatabaseStorageTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
class EventDatabaseStorageTests: XCTestCase {

    var eventStorage: EventDatabaseStorage!
    var userpilot: MockUserpilot!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        eventStorage = EventDatabaseStorage(container: userpilot.container)
    }

    override func tearDown() {
        // Clean up database
        eventStorage?.deleteAllEvents()

        // Wait for cleanup
        let expectation = XCTestExpectation(description: "Cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        eventStorage = nil
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createEvent(name: String) -> Event {
        return Event(type: .event(name))
    }

    private func createEventStorage(
        name: String, token: String = "NX-TEST", userId: String = "user_123"
    ) -> EventStorage? {
        let event = createEvent(name: name)
        return EventStorage(event, token, userId)
    }

    private func waitForAsyncOperation(timeout: TimeInterval = 1.0) {
        let expectation = XCTestExpectation(description: "Async operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    // MARK: - SaveEvent Tests

    func testSaveEvent_savesEventSuccessfully() {
        // Arrange
        guard let event = createEventStorage(name: "test_event") else {
            XCTFail("Failed to create event storage")
            return
        }

        let expectation = XCTestExpectation(description: "Save event")
        var saveResult: Bool?

        // Act
        eventStorage.saveEvent(event) { success in
            saveResult = success
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(saveResult ?? false)
        XCTAssertTrue(eventStorage.hasEvents())
    }

    func testSaveEvent_multipleEvents_savesAll() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2"),
            let event3 = createEventStorage(name: "event_3")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let expectation = XCTestExpectation(description: "Save events")
        expectation.expectedFulfillmentCount = 3
        var successCount = 0

        // Act
        eventStorage.saveEvent(event1) { success in
            if success { successCount += 1 }
            expectation.fulfill()
        }
        eventStorage.saveEvent(event2) { success in
            if success { successCount += 1 }
            expectation.fulfill()
        }
        eventStorage.saveEvent(event3) { success in
            if success { successCount += 1 }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(successCount, 3)

        waitForAsyncOperation()
        let stats = eventStorage.getStorageStats()
        XCTAssertEqual(stats.eventCount, 3)
    }

    func testSaveEvent_whenCountLimitReached_returnsFalse() {
        // Arrange
        let maxCount = Constants.Database.maxEventCount

        // Fill up to the limit
        let fillExpectation = XCTestExpectation(description: "Fill database")
        fillExpectation.expectedFulfillmentCount = maxCount

        for index in 0..<maxCount {
            if let event = createEventStorage(name: "event_\(index)") {
                eventStorage.saveEvent(event) { _ in
                    fillExpectation.fulfill()
                }
            }
        }

        wait(for: [fillExpectation], timeout: 10.0)
        waitForAsyncOperation()

        // Try to save one more
        guard let extraEvent = createEventStorage(name: "extra_event") else {
            XCTFail("Failed to create event storage")
            return
        }

        let expectation = XCTestExpectation(description: "Save event over limit")
        var saveResult: Bool?

        // Act
        eventStorage.saveEvent(extraEvent) { success in
            saveResult = success
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(saveResult ?? true)
    }

    // MARK: - GetAllEventsAndDelete Tests

    func testGetAllEventsAndDelete_returnsAllEvents() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2"),
            let event3 = createEventStorage(name: "event_3")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save events")
        saveExpectation.expectedFulfillmentCount = 3

        eventStorage.saveEvent(event1) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event2) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event3) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        let expectation = XCTestExpectation(description: "Get all events")
        var retrievedEvents: [EventStorage] = []

        // Act
        eventStorage.getAllEventsAndDelete { events in
            retrievedEvents = events
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(retrievedEvents.count, 3)
        XCTAssertFalse(eventStorage.hasEvents())
    }

    func testGetAllEventsAndDelete_whenEmpty_returnsEmptyArray() {
        // Arrange
        let expectation = XCTestExpectation(description: "Get all events")
        var retrievedEvents: [EventStorage]?

        // Act
        eventStorage.getAllEventsAndDelete { events in
            retrievedEvents = events
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(retrievedEvents)
        XCTAssertTrue(retrievedEvents?.isEmpty ?? false)
    }

    func testGetAllEventsAndDelete_deletesAllEvents() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save events")
        saveExpectation.expectedFulfillmentCount = 2

        eventStorage.saveEvent(event1) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event2) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        let expectation = XCTestExpectation(description: "Get all events")

        // Act
        eventStorage.getAllEventsAndDelete { _ in
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        waitForAsyncOperation()
        XCTAssertFalse(eventStorage.hasEvents())
        XCTAssertEqual(eventStorage.getStorageStats().eventCount, 0)
    }

    // MARK: - DeleteEvent Tests

    func testDeleteEvent_deletesSpecificEvent() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2"),
            let event3 = createEventStorage(name: "event_3")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save events")
        saveExpectation.expectedFulfillmentCount = 3

        eventStorage.saveEvent(event1) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event2) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event3) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act
        eventStorage.deleteEvent(event2)
        waitForAsyncOperation()

        // Assert
        let stats = eventStorage.getStorageStats()
        XCTAssertEqual(stats.eventCount, 2)
    }

    func testDeleteEvent_nonexistentEvent_doesNothing() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save event")
        eventStorage.saveEvent(event1) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act - Try to delete event that was never saved
        eventStorage.deleteEvent(event2)
        waitForAsyncOperation()

        // Assert
        let stats = eventStorage.getStorageStats()
        XCTAssertEqual(stats.eventCount, 1)
    }

    // MARK: - DeleteAllEvents Tests

    func testDeleteAllEvents_removesAllEvents() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2"),
            let event3 = createEventStorage(name: "event_3")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save events")
        saveExpectation.expectedFulfillmentCount = 3

        eventStorage.saveEvent(event1) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event2) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event3) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act
        eventStorage.deleteAllEvents()
        waitForAsyncOperation()

        // Assert
        XCTAssertFalse(eventStorage.hasEvents())
        XCTAssertEqual(eventStorage.getStorageStats().eventCount, 0)
    }

    func testDeleteAllEvents_onEmptyDatabase_doesNothing() {
        // Act
        eventStorage.deleteAllEvents()
        waitForAsyncOperation()

        // Assert
        XCTAssertFalse(eventStorage.hasEvents())
    }

    // MARK: - GetStorageStats Tests

    func testGetStorageStats_returnsCorrectStats() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save events")
        saveExpectation.expectedFulfillmentCount = 2

        eventStorage.saveEvent(event1) { _ in saveExpectation.fulfill() }
        eventStorage.saveEvent(event2) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act
        let stats = eventStorage.getStorageStats()

        // Assert
        XCTAssertEqual(stats.eventCount, 2)
        XCTAssertGreaterThan(stats.totalSizeBytes, 0)
        XCTAssertEqual(stats.maxEventCount, Constants.Database.maxEventCount)
        XCTAssertEqual(stats.maxSizeBytes, Constants.Database.maxSizeBytes)
        XCTAssertFalse(stats.isCountLimitReached)
        XCTAssertFalse(stats.isSizeLimitReached)
    }

    func testGetStorageStats_emptyDatabase_returnsZeroCounts() {
        // Act
        let stats = eventStorage.getStorageStats()

        // Assert
        XCTAssertEqual(stats.eventCount, 0)
        XCTAssertEqual(stats.totalSizeBytes, 0)
        XCTAssertFalse(stats.isCountLimitReached)
        XCTAssertFalse(stats.isSizeLimitReached)
    }

    func testGetStorageStats_tracksSize() {
        // Arrange
        guard let event = createEventStorage(name: "test_event") else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save event")
        eventStorage.saveEvent(event) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act
        let stats = eventStorage.getStorageStats()

        // Assert
        XCTAssertGreaterThan(stats.totalSizeBytes, 0)
        XCTAssertLessThan(stats.totalSizeBytes, stats.maxSizeBytes)
    }

    // MARK: - HasEvents Tests

    func testHasEvents_whenEmpty_returnsFalse() {
        // Act
        let hasEvents = eventStorage.hasEvents()

        // Assert
        XCTAssertFalse(hasEvents)
    }

    func testHasEvents_whenHasEvents_returnsTrue() {
        // Arrange
        guard let event = createEventStorage(name: "test_event") else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save event")
        eventStorage.saveEvent(event) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act
        let hasEvents = eventStorage.hasEvents()

        // Assert
        XCTAssertTrue(hasEvents)
    }

    func testHasEvents_afterDeleteAll_returnsFalse() {
        // Arrange
        guard let event = createEventStorage(name: "test_event") else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save event")
        eventStorage.saveEvent(event) { _ in saveExpectation.fulfill() }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        // Act
        eventStorage.deleteAllEvents()
        waitForAsyncOperation()

        let hasEvents = eventStorage.hasEvents()

        // Assert
        XCTAssertFalse(hasEvents)
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_concurrentSaves() {
        // Arrange
        let iterations = 10
        let expectation = XCTestExpectation(description: "Concurrent saves")
        expectation.expectedFulfillmentCount = iterations
        var successCount = 0
        let lock = NSLock()

        // Act
        for index in 0..<iterations {
            DispatchQueue.global().async {
                if let event = self.createEventStorage(name: "event_\(index)") {
                    self.eventStorage.saveEvent(event) { success in
                        if success {
                            lock.lock()
                            successCount += 1
                            lock.unlock()
                        }
                        expectation.fulfill()
                    }
                } else {
                    expectation.fulfill()
                }
            }
        }

        // Assert
        wait(for: [expectation], timeout: 5.0)
        waitForAsyncOperation()
        XCTAssertEqual(successCount, iterations)
    }

    func testThreadSafety_concurrentReadsAndWrites() {
        // Arrange
        let iterations = 5
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = iterations * 3

        // Act - Mix of saves, reads, and stat checks
        for index in 0..<iterations {
            DispatchQueue.global().async {
                if let event = self.createEventStorage(name: "event_\(index)") {
                    self.eventStorage.saveEvent(event) { _ in
                        expectation.fulfill()
                    }
                } else {
                    expectation.fulfill()
                }
            }

            DispatchQueue.global().async {
                _ = self.eventStorage.hasEvents()
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.eventStorage.getStorageStats()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 5.0)
        waitForAsyncOperation()
        // Should complete without crashes
        _ = eventStorage.getStorageStats()
    }

    // MARK: - Edge Cases

    func testSaveEvent_duplicateRequestId_replacesEvent() {
        // Arrange
        guard let event = createEventStorage(name: "test_event") else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation1 = XCTestExpectation(description: "Save event 1")
        eventStorage.saveEvent(event) { _ in saveExpectation1.fulfill() }

        wait(for: [saveExpectation1], timeout: 2.0)
        waitForAsyncOperation()

        // Act - Save same event again (same requestId)
        let saveExpectation2 = XCTestExpectation(description: "Save event 2")
        eventStorage.saveEvent(event) { _ in saveExpectation2.fulfill() }

        wait(for: [saveExpectation2], timeout: 2.0)
        waitForAsyncOperation()

        // Assert - Should still have only 1 event
        let stats = eventStorage.getStorageStats()
        XCTAssertEqual(stats.eventCount, 1)
    }

    func testGetAllEventsAndDelete_maintainsOrder() {
        // Arrange
        guard let event1 = createEventStorage(name: "event_1"),
            let event2 = createEventStorage(name: "event_2"),
            let event3 = createEventStorage(name: "event_3")
        else {
            XCTFail("Failed to create event storage")
            return
        }

        let saveExpectation = XCTestExpectation(description: "Save events")
        saveExpectation.expectedFulfillmentCount = 3

        // Save in specific order
        eventStorage.saveEvent(event1) { _ in
            saveExpectation.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.01)

        eventStorage.saveEvent(event2) { _ in
            saveExpectation.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.01)

        eventStorage.saveEvent(event3) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: 2.0)
        waitForAsyncOperation()

        let expectation = XCTestExpectation(description: "Get all events")
        var retrievedEvents: [EventStorage] = []

        // Act
        eventStorage.getAllEventsAndDelete { events in
            retrievedEvents = events
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(retrievedEvents.count, 3)

        // Verify order is maintained (ordered by created_at)
        if retrievedEvents.count == 3 {
            let event1Name = retrievedEvents[0].toEvent()?.eventTitle
            let event2Name = retrievedEvents[1].toEvent()?.eventTitle
            let event3Name = retrievedEvents[2].toEvent()?.eventTitle

            XCTAssertEqual(event1Name, "event_1")
            XCTAssertEqual(event2Name, "event_2")
            XCTAssertEqual(event3Name, "event_3")
        }
    }

}
// swiftlint:enable all
