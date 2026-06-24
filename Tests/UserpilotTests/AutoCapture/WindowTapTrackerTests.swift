//
//  WindowTapTrackerTests.swift
//  UserpilotTests
//

import CoreGraphics
import XCTest
@testable import Userpilot

final class WindowTapTrackerTests: XCTestCase {

    func testValidTapIsReturnedOnEnd() {
        let tracker = WindowTapTracker()
        let touch = NSObject()

        tracker.began(touch, at: CGPoint(x: 10, y: 10), timestamp: 1.0)
        let result = tracker.end(
            touch,
            at: CGPoint(x: 14, y: 13),
            timestamp: 1.2,
            maxMovement: 10,
            maxDuration: 0.5
        )

        XCTAssertEqual(result?.start, Optional(CGPoint(x: 10, y: 10)))
        XCTAssertEqual(result?.end, Optional(CGPoint(x: 14, y: 13)))
    }

    func testDragIsIgnoredOnEnd() {
        let tracker = WindowTapTracker()
        let touch = NSObject()

        tracker.began(touch, at: CGPoint(x: 10, y: 10), timestamp: 1.0)
        let result = tracker.end(
            touch,
            at: CGPoint(x: 40, y: 10),
            timestamp: 1.2,
            maxMovement: 10,
            maxDuration: 0.5
        )

        XCTAssertNil(result)
    }

    func testLongPressIsIgnoredOnEnd() {
        let tracker = WindowTapTracker()
        let touch = NSObject()

        tracker.began(touch, at: CGPoint(x: 10, y: 10), timestamp: 1.0)
        let result = tracker.end(
            touch,
            at: CGPoint(x: 11, y: 11),
            timestamp: 2.0,
            maxMovement: 10,
            maxDuration: 0.5
        )

        XCTAssertNil(result)
    }

    func testCancelledTouchIsForgotten() {
        let tracker = WindowTapTracker()
        let touch = NSObject()

        tracker.began(touch, at: CGPoint(x: 10, y: 10), timestamp: 1.0)
        tracker.forget(touch)

        let result = tracker.end(
            touch,
            at: CGPoint(x: 10, y: 10),
            timestamp: 1.1,
            maxMovement: 10,
            maxDuration: 0.5
        )

        XCTAssertNil(result)
    }
}
