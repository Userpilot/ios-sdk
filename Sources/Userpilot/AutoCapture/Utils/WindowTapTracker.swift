//
//  WindowTapTracker.swift
//  Userpilot
//
//  Tracks window-level touch starts so autocapture can distinguish real taps
//  from drags and long presses before resolving an interaction.
//

import CoreGraphics
import Foundation

internal final class WindowTapTracker {

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
