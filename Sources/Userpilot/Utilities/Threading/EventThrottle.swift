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

    // MARK: - Properties

    /// The minimum duration (in seconds) between consecutive events for the same name.
    private let throttleDuration: TimeInterval

    /// Tracks currently active generic events.
    private var activeEvents: Set<String> = []

    /// Tracks the currently active screen event (only one screen event is active at a time).
    private var activeScreenEvent: String?

    /// Serial dispatch queue for thread-safe operations.
    private let queue = DispatchQueue(label: Constants.DispatchQueues.throttleQueue)

    // MARK: - Initialization

    /**
     Initializes the EventThrottle with a specified throttle duration.
     
     - Parameter throttleDuration: The minimum time interval (in seconds) that must pass before the same event
       can be processed again.
     */
    init(throttleDuration: TimeInterval) {
        self.throttleDuration = throttleDuration
    }

    // MARK: - Public Methods

    /**
     Checks if a generic event should be throttled based on its name.
     
     - Parameter eventTitle: The name of the event to check.
     - Returns: `true` if the event should be throttled, `false` otherwise.
     */
    func shouldThrottle(eventTitle: String) -> Bool {
        return shouldThrottle(eventName: eventTitle, isScreenEvent: false)
    }

    /**
     Checks if a screen event should be throttled based on its name.
     
     - Parameter screenTitle: The name of the screen event to check.
     - Returns: `true` if the screen event should be throttled, `false` otherwise.
     */
    func shouldThrottleScreenEvent(screenTitle: String) -> Bool {
        return shouldThrottle(eventName: screenTitle, isScreenEvent: true)
    }

    /**
     Clears all tracked events (both generic and screen).
     */
    func clear() {
        queue.sync {
            activeEvents.removeAll()
            activeScreenEvent = nil
        }
    }

    /**
     Shuts down the throttle utility by clearing all active events.
     */
    func shutdown() {
        clear()
    }

    // MARK: - Private Methods

    /**
     Determines whether an event should be throttled, updating the active set if it's not throttled.
     
     - Parameters:
        - eventName: The name of the event to check.
        - isScreenEvent: `true` if this is a screen event, `false` otherwise.
     - Returns: `true` if the event should be throttled, `false` otherwise.
     */
    private func shouldThrottle(
        eventName: String,
        isScreenEvent: Bool
    ) -> Bool {
        return queue.sync {
            if isScreenEvent {
                // Throttle if the same screen event is active
                if activeScreenEvent == eventName {
                    return true
                } else {
                    activeScreenEvent = eventName
                    scheduleRemoval(of: eventName, isScreenEvent: true)
                    return false
                }
            } else {
                // Throttle if the same generic event is active
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

    /**
     Schedules the removal of an event from the appropriate active set after the throttle duration.
     
     - Parameters:
        - eventName: The name of the event to remove.
        - isScreenEvent: `true` if this is a screen event, `false` otherwise.
     */
    private func scheduleRemoval(
        of eventName: String,
        isScreenEvent: Bool
    ) {
        DispatchQueue.global().asyncAfter(deadline: .now() + throttleDuration) { [weak self] in
            guard let self else { return }
            self.queue.sync {
                if isScreenEvent {
                    if self.activeScreenEvent == eventName {
                        self.activeScreenEvent = nil
                    }
                } else {
                    self.activeEvents.remove(eventName)
                }
            }
        }
    }
}
