//
//  EventDebounceTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class EventDebounceTests: XCTestCase {

    func testLatestValueWinsForSameKey() {
        let expectation = expectation(description: "delivers latest")
        var delivered: [String] = []
        let debounce = EventDebounce<String>(
            delay: 0.03,
            deliveryQueue: .main
        ) { value in
            delivered.append(value)
            expectation.fulfill()
        }

        debounce.schedule(key: "field", value: "first")
        debounce.schedule(key: "field", value: "second")

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(delivered, ["second"])
        debounce.shutdown()
    }

    func testIndependentKeysBothDeliver() {
        let expectation = expectation(description: "delivers both keys")
        expectation.expectedFulfillmentCount = 2
        var delivered = Set<String>()
        let debounce = EventDebounce<String>(
            delay: 0.03,
            deliveryQueue: .main
        ) { value in
            delivered.insert(value)
            expectation.fulfill()
        }

        debounce.schedule(key: "a", value: "A")
        debounce.schedule(key: "b", value: "B")

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(delivered, ["A", "B"])
        debounce.shutdown()
    }

    func testCancelAllPreventsDelivery() {
        let inverted = expectation(description: "does not deliver")
        inverted.isInverted = true
        let debounce = EventDebounce<String>(
            delay: 0.05,
            deliveryQueue: .main
        ) { _ in
            inverted.fulfill()
        }

        debounce.schedule(key: "a", value: "A")
        debounce.cancelAll()

        wait(for: [inverted], timeout: 0.2)
    }

    func testShutdownPreventsDelivery() {
        let inverted = expectation(description: "does not deliver after shutdown")
        inverted.isInverted = true
        let debounce = EventDebounce<String>(
            delay: 0.05,
            deliveryQueue: .main
        ) { _ in
            inverted.fulfill()
        }

        debounce.schedule(key: "a", value: "A")
        debounce.shutdown()

        wait(for: [inverted], timeout: 0.2)
    }

    func testFlushPendingDeliversBufferedValuesImmediately() {
        var delivered: [String] = []
        let debounce = EventDebounce<String>(
            delay: 5,
            deliveryQueue: .main
        ) { value in
            delivered.append(value)
        }

        debounce.schedule(key: "field", value: "first")
        debounce.schedule(key: "field", value: "latest")
        // Let the scheduling hop onto the internal queue before flushing.
        let scheduled = expectation(description: "scheduled")
        DispatchQueue.main.async { scheduled.fulfill() }
        wait(for: [scheduled], timeout: 1)

        debounce.flushPending()

        // Called from the main thread with a main delivery queue, so delivery is inline: the caller can
        // publish its own event next and stay ordered after the flushed value.
        XCTAssertEqual(delivered, ["latest"])
        debounce.shutdown()
    }

    func testFlushPendingWithNothingPendingDeliversNothing() {
        let inverted = expectation(description: "does not deliver")
        inverted.isInverted = true
        let debounce = EventDebounce<String>(
            delay: 0.05,
            deliveryQueue: .main
        ) { _ in
            inverted.fulfill()
        }

        debounce.flushPending()

        wait(for: [inverted], timeout: 0.2)
    }

    func testFlushPendingClearsPendingWorkSoValuesDeliverOnce() {
        var delivered: [String] = []
        // The delay must be comfortably longer than the time it takes this test to reach
        // `flushPending()`. With a 0.05s delay the debounce timer could win that race under load,
        // so the test would silently exercise the timer path instead of the flush path it names —
        // and the timer would still be in flight when the test ended.
        let delay: TimeInterval = 0.5
        let debounce = EventDebounce<String>(
            delay: delay,
            deliveryQueue: .main
        ) { value in
            delivered.append(value)
        }

        debounce.schedule(key: "field", value: "A")
        // `flushPending()` takes `queue.sync`, so it is already ordered behind `schedule()`'s hop
        // onto the internal queue — no extra synchronization is needed for the value to be seen.
        debounce.flushPending()

        XCTAssertEqual(delivered, ["A"], "flushPending should deliver the buffered value inline")

        // Wait past the original delay: the cancelled timer must not deliver a second time.
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: delay + 2)

        XCTAssertEqual(delivered, ["A"], "cancelled timer must not deliver again")
        debounce.shutdown()
    }

    func testDeliveryUsesConfiguredQueue() {
        let expectation = expectation(description: "delivers on configured queue")
        let queueKey = DispatchSpecificKey<String>()
        let deliveryQueue = DispatchQueue(label: "com.userpilot.tests.debounce.delivery")
        deliveryQueue.setSpecific(key: queueKey, value: "delivery")
        let debounce = EventDebounce<String>(
            delay: 0.03,
            deliveryQueue: deliveryQueue
        ) { _ in
            XCTAssertEqual(DispatchQueue.getSpecific(key: queueKey), "delivery")
            expectation.fulfill()
        }

        debounce.schedule(key: "a", value: "A")

        wait(for: [expectation], timeout: 1)
        debounce.shutdown()
    }
}
