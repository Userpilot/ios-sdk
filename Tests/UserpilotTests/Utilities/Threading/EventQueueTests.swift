//
//  EventQueueTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest

@testable import Userpilot

// swiftlint:disable all
class EventQueueTests: XCTestCase {

    var eventQueue: EventQueue!

    override func setUp() {
        super.setUp()
        eventQueue = EventQueue()
    }

    override func tearDown() {
        eventQueue = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createEvent(name: String) -> Event {
        return Event(type: .event(name))
    }

    private func createScreenEvent(name: String) -> Event {
        return Event(type: .screen(name))
    }

    private func createIdentifyEvent(userId: String) -> Event {
        return Event(type: .identify(userId))
    }

    // MARK: - Enqueue Tests

    func testEnqueue_addsEventToQueue() {
        // Arrange
        let event = createEvent(name: "test_event")

        // Act
        eventQueue.enqueue(event)

        // Wait for async operation
        let expectation = XCTestExpectation(description: "Enqueue completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(eventQueue.size(), 1)
    }

    func testEnqueue_multipleEvents_addsAllToQueue() {
        // Arrange
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")
        let event3 = createEvent(name: "event_3")

        // Act
        eventQueue.enqueue(event1)
        eventQueue.enqueue(event2)
        eventQueue.enqueue(event3)

        // Wait for async operations
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(eventQueue.size(), 3)
    }

    // MARK: - Dequeue Tests

    func testDequeue_whenQueueIsEmpty_returnsNil() {
        // Act
        let result = eventQueue.dequeue()

        // Assert
        XCTAssertNil(result)
    }

    func testDequeue_whenQueueHasOneEvent_returnsEventAndRemovesIt() {
        // Arrange
        let event = createEvent(name: "test_event")
        eventQueue.enqueue(event)

        // Wait for enqueue
        let expectation = XCTestExpectation(description: "Enqueue completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let dequeuedEvent = eventQueue.dequeue()

        // Assert
        XCTAssertNotNil(dequeuedEvent)
        XCTAssertEqual(dequeuedEvent?.eventTitle, "test_event")
        XCTAssertEqual(eventQueue.size(), 0)
    }

    func testDequeue_maintainsFIFOOrder() {
        // Arrange
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")
        let event3 = createEvent(name: "event_3")

        eventQueue.enqueue(event1)
        eventQueue.enqueue(event2)
        eventQueue.enqueue(event3)

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act & Assert
        let first = eventQueue.dequeue()
        XCTAssertEqual(first?.eventTitle, "event_1")

        let second = eventQueue.dequeue()
        XCTAssertEqual(second?.eventTitle, "event_2")

        let third = eventQueue.dequeue()
        XCTAssertEqual(third?.eventTitle, "event_3")

        let fourth = eventQueue.dequeue()
        XCTAssertNil(fourth)
    }

    // MARK: - Peek Tests

    func testPeek_whenQueueIsEmpty_returnsNil() {
        // Act
        let result = eventQueue.peek()

        // Assert
        XCTAssertNil(result)
    }

    func testPeek_whenQueueHasEvents_returnsFirstEventWithoutRemoving() {
        // Arrange
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")

        eventQueue.enqueue(event1)
        eventQueue.enqueue(event2)

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let peekedEvent = eventQueue.peek()

        // Assert
        XCTAssertNotNil(peekedEvent)
        XCTAssertEqual(peekedEvent?.eventTitle, "event_1")
        XCTAssertEqual(eventQueue.size(), 2)  // Queue size should remain unchanged
    }

    func testPeek_multipleCalls_returnsSameEvent() {
        // Arrange
        let event = createEvent(name: "test_event")
        eventQueue.enqueue(event)

        // Wait for enqueue
        let expectation = XCTestExpectation(description: "Enqueue completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let peek1 = eventQueue.peek()
        let peek2 = eventQueue.peek()
        let peek3 = eventQueue.peek()

        // Assert
        XCTAssertEqual(peek1?.eventTitle, "test_event")
        XCTAssertEqual(peek2?.eventTitle, "test_event")
        XCTAssertEqual(peek3?.eventTitle, "test_event")
        XCTAssertEqual(eventQueue.size(), 1)
    }

    // MARK: - Size Tests

    func testSize_whenQueueIsEmpty_returnsZero() {
        // Act
        let size = eventQueue.size()

        // Assert
        XCTAssertEqual(size, 0)
    }

    func testSize_returnsCorrectCount() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let size = eventQueue.size()

        // Assert
        XCTAssertEqual(size, 3)
    }

    // MARK: - IsEmpty Tests

    func testIsEmpty_whenQueueIsEmpty_returnsTrue() {
        // Act
        let isEmpty = eventQueue.isEmpty()

        // Assert
        XCTAssertTrue(isEmpty)
    }

    func testIsEmpty_whenQueueHasEvents_returnsFalse() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "test_event"))

        // Wait for enqueue
        let expectation = XCTestExpectation(description: "Enqueue completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let isEmpty = eventQueue.isEmpty()

        // Assert
        XCTAssertFalse(isEmpty)
    }

    func testIsEmpty_afterClear_returnsTrue() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        // Wait for enqueues
        var expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        eventQueue.clear()

        // Wait for clear
        expectation = XCTestExpectation(description: "Clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - Clear Tests

    func testClear_removesAllEvents() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        // Wait for enqueues
        var expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        eventQueue.clear()

        // Wait for clear
        expectation = XCTestExpectation(description: "Clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(eventQueue.size(), 0)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    func testClear_onEmptyQueue_doesNothing() {
        // Act
        eventQueue.clear()

        // Wait for clear
        let expectation = XCTestExpectation(description: "Clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(eventQueue.size(), 0)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - DeleteFirst Tests

    func testDeleteFirst_removesFirstEvent() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        // Wait for enqueues
        var expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        eventQueue.deleteFirst()

        // Wait for delete
        expectation = XCTestExpectation(description: "Delete completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(eventQueue.size(), 1)
        XCTAssertEqual(eventQueue.peek()?.eventTitle, "event_2")
    }

    func testDeleteFirst_onEmptyQueue_doesNothing() {
        // Act
        eventQueue.deleteFirst()

        // Wait for delete
        let expectation = XCTestExpectation(description: "Delete completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(eventQueue.size(), 0)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - GetAll Tests

    func testGetAll_whenQueueIsEmpty_returnsEmptyArray() {
        // Act
        let events = eventQueue.getAll()

        // Assert
        XCTAssertTrue(events.isEmpty)
    }

    func testGetAll_returnsAllEventsInOrder() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let events = eventQueue.getAll()

        // Assert
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].eventTitle, "event_1")
        XCTAssertEqual(events[1].eventTitle, "event_2")
        XCTAssertEqual(events[2].eventTitle, "event_3")
    }

    func testGetAll_doesNotModifyQueue() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let events = eventQueue.getAll()

        // Assert
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(eventQueue.size(), 2)  // Queue size should remain unchanged
    }

    // MARK: - Contains Tests

    func testContains_whenEventExists_returnsTrue() {
        // Arrange
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")

        eventQueue.enqueue(event1)
        eventQueue.enqueue(event2)

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let contains = eventQueue.contains(event1) { eventOne, eventTwo in
            eventOne.eventTitle == eventTwo.eventTitle
        }

        // Assert
        XCTAssertTrue(contains)
    }

    func testContains_whenEventDoesNotExist_returnsFalse() {
        // Arrange
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")

        eventQueue.enqueue(event1)

        // Wait for enqueue
        let expectation = XCTestExpectation(description: "Enqueue completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let contains = eventQueue.contains(event2) { eventOne, eventTwo in
            eventOne.eventTitle == eventTwo.eventTitle
        }

        // Assert
        XCTAssertFalse(contains)
    }

    // MARK: - Find Tests

    func testFind_whenEventExists_returnsEvent() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let foundEvent = eventQueue.find { event in
            event.eventTitle == "event_2"
        }

        // Assert
        XCTAssertNotNil(foundEvent)
        XCTAssertEqual(foundEvent?.eventTitle, "event_2")
    }

    func testFind_whenEventDoesNotExist_returnsNil() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))

        // Wait for enqueue
        let expectation = XCTestExpectation(description: "Enqueue completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let foundEvent = eventQueue.find { event in
            event.eventTitle == "nonexistent"
        }

        // Assert
        XCTAssertNil(foundEvent)
    }

    // MARK: - GetFirst Tests

    func testGetFirst_whenQueueIsEmpty_returnsNil() {
        // Act
        let first = eventQueue.getFirst()

        // Assert
        XCTAssertNil(first)
    }

    func testGetFirst_returnsFirstEventWithoutRemoving() {
        // Arrange
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        // Wait for enqueues
        let expectation = XCTestExpectation(description: "Enqueues completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act
        let first = eventQueue.getFirst()

        // Assert
        XCTAssertEqual(first?.eventTitle, "event_1")
        XCTAssertEqual(eventQueue.size(), 2)  // Queue size should remain unchanged
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_concurrentEnqueues() {
        // Arrange
        let iterations = 100
        let expectation = XCTestExpectation(description: "Concurrent enqueues")
        expectation.expectedFulfillmentCount = iterations

        // Act
        for index in 0..<iterations {
            DispatchQueue.global().async {
                self.eventQueue.enqueue(self.createEvent(name: "event_\(index)"))
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 5.0)

        // Wait for all enqueues to complete
        let waitExpectation = XCTestExpectation(description: "Wait for completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        XCTAssertEqual(eventQueue.size(), iterations)
    }

    func testThreadSafety_concurrentDequeues() {
        // Arrange
        let iterations = 100
        for index in 0..<iterations {
            eventQueue.enqueue(createEvent(name: "event_\(index)"))
        }

        // Wait for enqueues
        var waitExpectation = XCTestExpectation(description: "Wait for enqueues")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        let expectation = XCTestExpectation(description: "Concurrent dequeues")
        expectation.expectedFulfillmentCount = iterations

        // Act
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                _ = self.eventQueue.dequeue()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 5.0)

        // Wait for all dequeues to complete
        waitExpectation = XCTestExpectation(description: "Wait for completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        XCTAssertEqual(eventQueue.size(), 0)
    }

//    func testThreadSafety_mixedOperations() {
//        // Arrange
//        let iterations = 25  // Reduced to avoid timeout with async operations
//        let expectation = XCTestExpectation(description: "Mixed operations")
//        expectation.expectedFulfillmentCount = iterations * 4
//
//        // Act - Mix of enqueues, dequeues, peeks, and size checks
//        for i in 0..<iterations {
//            DispatchQueue.global().async {
//                self.eventQueue.enqueue(self.createEvent(name: "event_\(i)"))
//                expectation.fulfill()
//            }
//
//            DispatchQueue.global().async {
//                _ = self.eventQueue.dequeue()
//                expectation.fulfill()
//            }
//
//            DispatchQueue.global().async {
//                _ = self.eventQueue.peek()
//                expectation.fulfill()
//            }
//
//            DispatchQueue.global().async {
//                _ = self.eventQueue.size()
//                expectation.fulfill()
//            }
//        }
//
//        // Assert
//        wait(for: [expectation], timeout: 15.0)  // Increased timeout for reliability
//
//        // Queue should be in a valid state (not crashed)
//        _ = eventQueue.size()
//    }
}
// swiftlint:enable all
