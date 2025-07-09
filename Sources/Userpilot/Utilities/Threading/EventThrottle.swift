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

internal class EventThrottle {

    /// The minimum duration (in seconds) between consecutive events for the same name.
    private let throttleDuration: TimeInterval

    /// Tracks active generic events.
    private var activeEvents: Set<String> = []

    /// Tracks the active screen event (only one at a time).
    private var activeScreenEvent: String?

    private let queue = DispatchQueue(label: DispatchQueueConstants.THROTTLE_QUEUE)

    /// Initializes the EventThrottle with a specified throttle duration.
    /// - Parameter throttleDuration: The time interval (in seconds) that must pass before the same event
    ///   can be processed again.
    init(throttleDuration: TimeInterval) {
        self.throttleDuration = throttleDuration
    }

    /// Determines whether a generic event should be throttled based on its name.
    ///
    /// - Parameter eventName: The name of the event to check.
    /// - Returns: `true` if the event should be throttled; `false` otherwise.
    func shouldThrottle(eventTitle: String) -> Bool {
        return shouldThrottle(eventName: eventTitle, isScreenEvent: false)
    }

    /// Determines whether a screen event should be throttled based on its name.
    ///
    /// - Parameter eventName: The name of the screen event to check.
    /// - Returns: `true` if the screen event should be throttled; `false` otherwise.
    func shouldThrottleScreenEvent(screenTitle: String) -> Bool {
        return shouldThrottle(eventName: screenTitle, isScreenEvent: true)
    }

    /// Determines whether an event should be throttled, updating the active set if it’s not throttled.
    ///
    /// - Parameters:
    ///   - eventName: The name of the event to check.
    ///   - isScreenEvent: `true` if this is a screen event, `false` otherwise.
    /// - Returns: `true` if the event should be throttled; `false` otherwise.
    private func shouldThrottle(
        eventName: String,
        isScreenEvent: Bool
    ) -> Bool {
        return queue.sync {
            if isScreenEvent {
                if activeScreenEvent == eventName {
                    return true
                } else {
                    activeScreenEvent = eventName
                    scheduleRemoval(of: eventName, isScreenEvent: true)
                    return false
                }
            } else {
                if activeEvents.contains(eventName) {
                    return true
                } else {
                    activeEvents.insert(eventName)
                    scheduleRemoval(of: eventName, isScreenEvent: false)
                    return false
                }
            }
        }
    }

    /// Schedules the removal of an event from the appropriate active set after the throttle duration.
    ///
    /// - Parameters:
    ///   - eventName: The name of the event to remove.
    ///   - isScreenEvent: `true` if this is a screen event, `false` otherwise.
    private func scheduleRemoval(
        of eventName: String,
        isScreenEvent: Bool
    ) {
        tryCatch {
            DispatchQueue.global().asyncAfter(deadline: .now() + throttleDuration) { [weak self] in
                self?.queue.sync {
                    if isScreenEvent {
                        if self?.activeScreenEvent == eventName {
                            self?.activeScreenEvent = nil
                        }
                    } else {
                        self?.activeEvents.remove(eventName)
                    }
                }
            }
        }
    }

    /// Clears all tracked events (both generic and screen).
    func clear() {
        queue.sync {
            activeEvents.removeAll()
            activeScreenEvent = nil
        }
    }

    /// Shuts down the throttle utility.
    func shutdown() {
        clear()
    }
}
