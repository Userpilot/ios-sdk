//
//  WindowTapTrackerTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Checks tap movement, cancellation and one-click-per-touch decisions.
//

import CoreGraphics
import UIKit
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

// MARK: - One click per touch

/// `sendEvent` asks `shouldCapture` once per touch per event; every test counts the clicks
/// a whole touch sequence publishes, which must never exceed one.
final class WindowTapCaptureDecisionTests: XCTestCase {

    private struct Step {
        let phase: UITouch.Phase
        var point = CGPoint(x: 50, y: 50)
        let time: TimeInterval
        var touchCount = 1
        let tapEnd: Bool
    }

    private func clicks(_ steps: [Step], tracker: WindowTapTracker = WindowTapTracker(),
                        touch: AnyObject = NSObject()) -> Int {
        steps.filter {
            tracker.shouldCapture(touch, phase: $0.phase, at: $0.point, timestamp: $0.time,
                                  touchCount: $0.touchCount, capturesOnTapEnd: $0.tapEnd)
        }.count
    }

    func testTouchBeganMode_publishesOnceAtTouchBegan() {
        let tracker = WindowTapTracker()
        let touch = NSObject()

        XCTAssertTrue(tracker.shouldCapture(touch, phase: .began, at: .zero, timestamp: 1,
                                            touchCount: 1, capturesOnTapEnd: false))
        XCTAssertEqual(clicks([
            Step(phase: .moved, time: 1.1, tapEnd: false),
            Step(phase: .stationary, time: 1.2, tapEnd: false),
            Step(phase: .ended, time: 1.3, tapEnd: false)
        ], tracker: tracker, touch: touch), 0)
    }

    func testTapEndMode_publishesARealTapOnceAtTouchEnd() {
        let tracker = WindowTapTracker()
        let touch = NSObject()

        XCTAssertEqual(clicks([
            Step(phase: .began, time: 1.0, tapEnd: true),
            Step(phase: .moved, point: CGPoint(x: 53, y: 54), time: 1.1, tapEnd: true)
        ], tracker: tracker, touch: touch), 0, "nothing is published before the finger lifts")
        XCTAssertTrue(tracker.shouldCapture(touch, phase: .ended, at: CGPoint(x: 53, y: 54), timestamp: 1.2,
                                            touchCount: 1, capturesOnTapEnd: true))
    }

    func testTapEndMode_scrollStartingOnAButtonIsNotAClick() {
        XCTAssertEqual(clicks([
            Step(phase: .began, time: 1.0, tapEnd: true),
            Step(phase: .moved, point: CGPoint(x: 50, y: 120), time: 1.1, tapEnd: true),
            Step(phase: .ended, point: CGPoint(x: 50, y: 200), time: 1.2, tapEnd: true)
        ]), 0)
    }

    func testTapEndMode_longPressIsNotAClick() {
        XCTAssertEqual(clicks([
            Step(phase: .began, time: 1.0, tapEnd: true),
            Step(phase: .ended, time: 1.0 + WindowTapTracker.maxTapDuration + 0.1, tapEnd: true)
        ]), 0)
    }

    func testTapEndMode_cancelledTouchIsNotAClick() {
        XCTAssertEqual(clicks([
            Step(phase: .began, time: 1.0, tapEnd: true),
            Step(phase: .cancelled, time: 1.1, tapEnd: true),
            Step(phase: .ended, time: 1.2, tapEnd: true)
        ]), 0)
    }

    func testTapEndMode_multiFingerTapIsNotAClick() {
        let tracker = WindowTapTracker()
        let first = NSObject()
        let second = NSObject()

        let published = [first, second].map { touch in
            clicks([
                Step(phase: .began, time: 1.0, touchCount: 2, tapEnd: true),
                Step(phase: .ended, time: 1.1, touchCount: 2, tapEnd: true)
            ], tracker: tracker, touch: touch)
        }

        XCTAssertEqual(published, [0, 0])
    }

    func testModeChangeMidTouch_neverPublishesTwice() {
        // Began before the framework was detected (touch-began), ended in tap-end mode.
        XCTAssertEqual(clicks([
            Step(phase: .began, time: 1.0, tapEnd: false),
            Step(phase: .ended, time: 1.1, tapEnd: true)
        ]), 1)
        // Began in tap-end mode, ended after the mode turned off.
        XCTAssertEqual(clicks([
            Step(phase: .began, time: 1.0, tapEnd: true),
            Step(phase: .ended, time: 1.1, tapEnd: false)
        ]), 0)
    }

    func testRepeatedTaps_publishOneClickEach() {
        let tracker = WindowTapTracker()
        let touch = NSObject()
        let tap = [
            Step(phase: .began, time: 1.0, tapEnd: true),
            Step(phase: .ended, time: 1.1, tapEnd: true)
        ]

        XCTAssertEqual(clicks(tap + tap + tap, tracker: tracker, touch: touch), 3)
    }
}
