//
//  AnalyticsPublisherTestSupport.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Waits for real publisher/main queue boundaries so assertions do not depend on scheduler timing.
//

import XCTest
@testable import Userpilot

extension AnalyticsPublisher {
    func testSettle() {
        // Close completion can enqueue a reconnect back to main; settle both round trips.
        for _ in 0..<2 {
            mockWaitForQueue()
            let mainDrained = XCTestExpectation(description: "analytics main callbacks drained")
            DispatchQueue.main.async { mainDrained.fulfill() }
            XCTAssertEqual(XCTWaiter.wait(for: [mainDrained], timeout: 2), .completed)
        }
        mockWaitForQueue()
    }

    func testPublish(_ event: Event) {
        publish(event)
        testSettle()
    }

    func testPublishInternalSDKEvent(_ event: SDKEvent) {
        publishInternalSDKEvent(event)
        testSettle()
    }

    func testFlush() {
        flush()
        testSettle()
    }

    func testResume() {
        resume()
        testSettle()
    }

    func testReset() {
        reset()
        testSettle()
    }

    func testOnSocketOpened() {
        onSocketOpened()
        testSettle()
    }

    func testOnSocketClosed() {
        onSocketClosed()
        testSettle()
    }
}
