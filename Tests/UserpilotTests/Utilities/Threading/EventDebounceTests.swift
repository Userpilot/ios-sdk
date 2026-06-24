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
    }
}
