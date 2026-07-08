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
        let event = createEvent(name: "test_event")

        eventQueue.enqueue(event)

        XCTAssertEqual(eventQueue.size(), 1)
    }

    func testEnqueue_multipleEvents_addsAllToQueue() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        XCTAssertEqual(eventQueue.size(), 3)
    }

    // MARK: - Dequeue Tests

    func testDequeue_whenQueueIsEmpty_returnsNil() {
        XCTAssertNil(eventQueue.dequeue())
    }

    func testDequeue_whenQueueHasOneEvent_returnsEventAndRemovesIt() {
        eventQueue.enqueue(createEvent(name: "test_event"))

        let dequeuedEvent = eventQueue.dequeue()

        XCTAssertNotNil(dequeuedEvent)
        XCTAssertEqual(dequeuedEvent?.eventTitle, "test_event")
        XCTAssertEqual(eventQueue.size(), 0)
    }

    func testDequeue_maintainsFIFOOrder() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "event_1")
        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "event_2")
        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "event_3")
        XCTAssertNil(eventQueue.dequeue())
    }

    // MARK: - Peek Tests

    func testPeek_whenQueueIsEmpty_returnsNil() {
        XCTAssertNil(eventQueue.peek())
    }

    func testPeek_whenQueueHasEvents_returnsFirstEventWithoutRemoving() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        let peekedEvent = eventQueue.peek()

        XCTAssertNotNil(peekedEvent)
        XCTAssertEqual(peekedEvent?.eventTitle, "event_1")
        XCTAssertEqual(eventQueue.size(), 2)
    }

    func testPeek_multipleCalls_returnsSameEvent() {
        eventQueue.enqueue(createEvent(name: "test_event"))

        XCTAssertEqual(eventQueue.peek()?.eventTitle, "test_event")
        XCTAssertEqual(eventQueue.peek()?.eventTitle, "test_event")
        XCTAssertEqual(eventQueue.peek()?.eventTitle, "test_event")
        XCTAssertEqual(eventQueue.size(), 1)
    }

    // MARK: - Size Tests

    func testSize_whenQueueIsEmpty_returnsZero() {
        XCTAssertEqual(eventQueue.size(), 0)
    }

    func testSize_returnsCorrectCount() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        XCTAssertEqual(eventQueue.size(), 3)
    }

    // MARK: - IsEmpty Tests

    func testIsEmpty_whenQueueIsEmpty_returnsTrue() {
        XCTAssertTrue(eventQueue.isEmpty())
    }

    func testIsEmpty_whenQueueHasEvents_returnsFalse() {
        eventQueue.enqueue(createEvent(name: "test_event"))

        XCTAssertFalse(eventQueue.isEmpty())
    }

    func testIsEmpty_afterClear_returnsTrue() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        eventQueue.clear()

        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - Clear Tests

    func testClear_removesAllEvents() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        eventQueue.clear()

        XCTAssertEqual(eventQueue.size(), 0)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    func testClear_onEmptyQueue_doesNothing() {
        eventQueue.clear()

        XCTAssertEqual(eventQueue.size(), 0)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - DeleteFirst Tests

    func testDeleteFirst_removesFirstEvent() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        eventQueue.deleteFirst()

        XCTAssertEqual(eventQueue.size(), 1)
        XCTAssertEqual(eventQueue.peek()?.eventTitle, "event_2")
    }

    func testDeleteFirst_onEmptyQueue_doesNothing() {
        eventQueue.deleteFirst()

        XCTAssertEqual(eventQueue.size(), 0)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - GetAll Tests

    func testGetAll_whenQueueIsEmpty_returnsEmptyArray() {
        XCTAssertTrue(eventQueue.getAll().isEmpty)
    }

    func testGetAll_returnsAllEventsInOrder() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        let events = eventQueue.getAll()

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].eventTitle, "event_1")
        XCTAssertEqual(events[1].eventTitle, "event_2")
        XCTAssertEqual(events[2].eventTitle, "event_3")
    }

    func testGetAll_doesNotModifyQueue() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        let events = eventQueue.getAll()

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(eventQueue.size(), 2)
    }

    // MARK: - GetAndClear Tests

    func testGetAndClear_returnsAllEventsAndClearsQueue() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        let events = eventQueue.getAndClear()

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventTitle, "event_1")
        XCTAssertEqual(events[1].eventTitle, "event_2")
        XCTAssertTrue(eventQueue.isEmpty())
    }

    func testGetAndClear_whenQueueIsEmpty_returnsEmptyArray() {
        let events = eventQueue.getAndClear()

        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(eventQueue.isEmpty())
    }

    // MARK: - Contains Tests

    func testContains_whenEventExists_returnsTrue() {
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")
        eventQueue.enqueue(event1)
        eventQueue.enqueue(event2)

        let contains = eventQueue.contains(event1) { eventOne, eventTwo in
            eventOne.eventTitle == eventTwo.eventTitle
        }

        XCTAssertTrue(contains)
    }

    func testContains_whenEventDoesNotExist_returnsFalse() {
        let event1 = createEvent(name: "event_1")
        let event2 = createEvent(name: "event_2")
        eventQueue.enqueue(event1)

        let contains = eventQueue.contains(event2) { eventOne, eventTwo in
            eventOne.eventTitle == eventTwo.eventTitle
        }

        XCTAssertFalse(contains)
    }

    // MARK: - Find Tests

    func testFind_whenEventExists_returnsEvent() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))
        eventQueue.enqueue(createEvent(name: "event_3"))

        let foundEvent = eventQueue.find { event in
            event.eventTitle == "event_2"
        }

        XCTAssertNotNil(foundEvent)
        XCTAssertEqual(foundEvent?.eventTitle, "event_2")
    }

    func testFind_whenEventDoesNotExist_returnsNil() {
        eventQueue.enqueue(createEvent(name: "event_1"))

        let foundEvent = eventQueue.find { event in
            event.eventTitle == "nonexistent"
        }

        XCTAssertNil(foundEvent)
    }

    // MARK: - GetFirst Tests

    func testGetFirst_whenQueueIsEmpty_returnsNil() {
        XCTAssertNil(eventQueue.getFirst())
    }

    func testGetFirst_returnsFirstEventWithoutRemoving() {
        eventQueue.enqueue(createEvent(name: "event_1"))
        eventQueue.enqueue(createEvent(name: "event_2"))

        let first = eventQueue.getFirst()

        XCTAssertEqual(first?.eventTitle, "event_1")
        XCTAssertEqual(eventQueue.size(), 2)
    }

    // MARK: - Prioritization Tests

    func testEnqueue_internalEvent_addsEventToFront() {
        eventQueue.enqueue(createEvent(name: "regular_event"))
        eventQueue.enqueue(createEvent(name: "internal_event"), isInternalEvent: true)

        XCTAssertEqual(eventQueue.getFirst()?.eventTitle, "internal_event")
    }

    func testEnqueue_multipleInternalEvents_preservesInternalLifoOrder() {
        eventQueue.enqueue(createEvent(name: "regular_event"))
        eventQueue.enqueue(createEvent(name: "internal_1"), isInternalEvent: true)
        eventQueue.enqueue(createEvent(name: "internal_2"), isInternalEvent: true)

        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "internal_2")
        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "internal_1")
        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "regular_event")
    }

    func testQueueSupportsDifferentEventTypes() {
        eventQueue.enqueue(createEvent(name: "track_event"))
        eventQueue.enqueue(createScreenEvent(name: "Home"))
        eventQueue.enqueue(createIdentifyEvent(userId: "user-1"))

        XCTAssertEqual(eventQueue.dequeue()?.eventTitle, "track_event")
        XCTAssertEqual(eventQueue.dequeue()?.screenTitle, "Home")
        XCTAssertEqual(eventQueue.dequeue()?.userId, "user-1")
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_concurrentEnqueues() {
        let iterations = 100
        let expectation = XCTestExpectation(description: "Concurrent enqueues")
        expectation.expectedFulfillmentCount = iterations

        for index in 0..<iterations {
            DispatchQueue.global().async {
                self.eventQueue.enqueue(self.createEvent(name: "event_\(index)"))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(eventQueue.size(), iterations)
    }

    func testThreadSafety_concurrentDequeues() {
        let iterations = 100
        for index in 0..<iterations {
            eventQueue.enqueue(createEvent(name: "event_\(index)"))
        }

        let expectation = XCTestExpectation(description: "Concurrent dequeues")
        expectation.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                _ = self.eventQueue.dequeue()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(eventQueue.size(), 0)
    }
}
// swiftlint:enable all
