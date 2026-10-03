//
//  EventThrottle.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 11/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Implements event throttling to prevent processing events with the same name
//  more frequently than the specified throttle duration. Supports both generic
//  and screen-specific event types.
//

import Foundation

/// Synchronous throttle checks and resets are safe to call from any thread.
/// Expiration uses monotonic time; rejected duplicates do not extend the throttle period.
internal class EventThrottle {

    private let throttleDuration: TimeInterval
    private let lock = NSLock()

    private var eventExpirations: [String: DispatchTime] = [:]
    private var activeScreen: (name: String, expiresAt: DispatchTime)?

    init(throttleDuration: TimeInterval) {
        self.throttleDuration = throttleDuration
    }

    /// Returns true while the same generic event is within its throttle period.
    func shouldThrottle(eventTitle: String) -> Bool {
        lock.withLock {
            let now = DispatchTime.now()

            // Remove expired keys so old event names do not accumulate.
            eventExpirations = eventExpirations.filter {
                $0.value > now
            }

            if eventExpirations[eventTitle] != nil {
                return true
            }

            eventExpirations[eventTitle] = now + throttleDuration
            return false
        }
    }

    /// Throttles repeats of the current screen; a different screen is accepted immediately.
    func shouldThrottleScreenEvent(screenTitle: String) -> Bool {
        lock.withLock {
            let now = DispatchTime.now()

            if let screen = activeScreen,
               screen.name == screenTitle,
               now < screen.expiresAt {
                return true
            }

            // A different screen, or an expired repeat, starts a new window.
            activeScreen = (
                name: screenTitle,
                expiresAt: now + throttleDuration
            )
            return false
        }
    }

    /// Clears generic and screen throttle periods immediately.
    func clear() {
        lock.withLock {
            eventExpirations.removeAll()
            activeScreen = nil
        }
    }

    /// Clears pending throttle state. Alias for `clear()`.
    func shutdown() {
        clear()
    }
}
