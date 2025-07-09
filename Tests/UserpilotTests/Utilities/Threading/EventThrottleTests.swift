//
//  EventThrottleTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class EventThrottleTests: XCTestCase {
    
    var throttle: EventThrottle!
    let throttleDuration: TimeInterval = 0.2

    override func setUp() {
        super.setUp()
        throttle = EventThrottle(throttleDuration: throttleDuration)
    }

    override func tearDown() {
        throttle = nil
        super.tearDown()
    }

    func testThrottleGenericEvent_FirstCallNotThrottled() {
        let event = "generic_event"
        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))
    }

    func testThrottleGenericEvent_SecondCallWithinDurationIsThrottled() {
        let event = "generic_event"
        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))
        XCTAssertTrue(throttle.shouldThrottle(eventTitle: event))
    }

    func testThrottleGenericEvent_AfterDurationNotThrottled() {
        let event = "generic_event"
        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))

        let expectation = XCTestExpectation(description: "Wait for throttle to expire")
        DispatchQueue.global().asyncAfter(deadline: .now() + throttleDuration + 0.1) {
            XCTAssertFalse(self.throttle.shouldThrottle(eventTitle: event))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: throttleDuration + 0.5)
    }

    func testThrottleScreenEvent_FirstCallNotThrottled() {
        let event = "screen_event"
        XCTAssertFalse(throttle.shouldThrottleScreenEvent(screenTitle: event))
    }

    func testThrottleScreenEvent_SecondCallWithinDurationIsThrottled() {
        let event = "screen_event"
        XCTAssertFalse(throttle.shouldThrottleScreenEvent(screenTitle: event))
        XCTAssertTrue(throttle.shouldThrottleScreenEvent(screenTitle: event))
    }

    func testThrottleScreenEvent_AfterDurationNotThrottled() {
        let event = "screen_event"
        XCTAssertFalse(throttle.shouldThrottleScreenEvent(screenTitle: event))

        let expectation = XCTestExpectation(description: "Wait for screen throttle to expire")
        DispatchQueue.global().asyncAfter(deadline: .now() + throttleDuration + 0.1) {
            XCTAssertFalse(self.throttle.shouldThrottleScreenEvent(screenTitle: event))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: throttleDuration + 0.5)
    }

    func testGenericAndScreenEventsAreIndependent() {
        let genericEvent = "generic_event"
        let screenEvent = "screen_event"

        XCTAssertFalse(throttle.shouldThrottle(eventTitle: genericEvent))
        XCTAssertFalse(throttle.shouldThrottleScreenEvent(screenTitle: screenEvent))

        XCTAssertTrue(throttle.shouldThrottle(eventTitle: genericEvent))
        XCTAssertTrue(throttle.shouldThrottleScreenEvent(screenTitle: screenEvent))
    }

    func testClearResetsThrottle() {
        let event = "event"

        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))
        XCTAssertTrue(throttle.shouldThrottle(eventTitle: event))

        throttle.clear()

        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))
    }

    func testShutdownCallsClear() {
        let event = "event"

        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))
        XCTAssertTrue(throttle.shouldThrottle(eventTitle: event))

        throttle.shutdown()

        XCTAssertFalse(throttle.shouldThrottle(eventTitle: event))
    }
}
