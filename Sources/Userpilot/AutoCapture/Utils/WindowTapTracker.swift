//
//  WindowTapTracker.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Tracks window-level touch starts so autocapture can distinguish real taps
//  from drags and long presses before resolving an interaction.
//

import UIKit

/// Main-thread state owned by UIWindow.sendEvent; touch sequences never cross queues.
internal final class WindowTapTracker {

    /// A real tap moves at most this far (points) between touch began and ended.
    static let maxTapMovement: CGFloat = 10

    /// A real tap lasts at most this long (seconds); longer is a long press.
    static let maxTapDuration: TimeInterval = 0.5

    struct Tap {
        let start: CGPoint
        let end: CGPoint
        let startTimestamp: TimeInterval
        let endTimestamp: TimeInterval
    }

    private struct Start {
        let point: CGPoint
        let timestamp: TimeInterval
    }

    private var starts: [ObjectIdentifier: Start] = [:]

    // Whether `touch` publishes a click in `phase`. A touch publishes at most once: at
    // `.began` in touch-began mode, or at `.ended` of a real single-finger tap in tap-end
    // mode. A touch that began in one mode and ends in the other publishes nothing more.
    // `touchCount` is `event.allTouches.count`; `capturesOnTapEnd` is the mode for this
    // event (see `SwiftUITitleCapturePolicy.capturesClicksOnTapEnd`).
    // swiftlint:disable:next function_parameter_count
    func shouldCapture(
        _ touch: AnyObject,
        phase: UITouch.Phase,
        at point: CGPoint,
        timestamp: TimeInterval,
        touchCount: Int,
        capturesOnTapEnd: Bool
    ) -> Bool {
        switch phase {
        case .began where capturesOnTapEnd:
            began(touch, at: point, timestamp: timestamp)
            return false

        case .began:
            return true

        case .ended where capturesOnTapEnd:
            let tap = end(
                touch,
                at: point,
                timestamp: timestamp,
                maxMovement: Self.maxTapMovement,
                maxDuration: Self.maxTapDuration
            )
            return tap != nil && touchCount == 1

        case .cancelled:
            forget(touch)
            return false

        default:
            return false
        }
    }

    func began(_ touch: AnyObject, at point: CGPoint, timestamp: TimeInterval) {
        // Defensive cap: touch sequences should end/cancel, but do not let a
        // malformed stream grow this table indefinitely.
        if starts.count > 16 { starts.removeAll() }
        starts[ObjectIdentifier(touch)] = Start(point: point, timestamp: timestamp)
    }

    func end(
        _ touch: AnyObject,
        at point: CGPoint,
        timestamp: TimeInterval,
        maxMovement: CGFloat,
        maxDuration: TimeInterval
    ) -> Tap? {
        let key = ObjectIdentifier(touch)
        defer { starts[key] = nil }
        guard let start = starts[key] else { return nil }

        let moved = hypot(point.x - start.point.x, point.y - start.point.y)
        let duration = timestamp - start.timestamp
        guard moved <= maxMovement, duration <= maxDuration else { return nil }

        return Tap(
            start: start.point,
            end: point,
            startTimestamp: start.timestamp,
            endTimestamp: timestamp
        )
    }

    func forget(_ touch: AnyObject) {
        starts[ObjectIdentifier(touch)] = nil
    }
}
