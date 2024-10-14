//
//  EventType.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `EventType` enum represents different types of events that can be tracked in the UserPilot SDK.
//  These include custom events, screen views, and user identity grouping.
//

import Foundation

/**
 The `EventType` enum is used to categorize and manage different types of events within the UserPilot SDK.

 It defines three types of events:
 - `event`: Tracks custom events, such as button clicks or other user interactions.
 - `screen`: Tracks screen views, logging when a particular screen is opened.
 - `identify`: Tracks a user being identified, either as part of a company or based on their unique ID.

 The enum also provides utility methods to retrieve metadata (such as event name and user ID) and check event types.
 */
internal enum EventType: Equatable {

    /// Custom event for tracking a user action (e.g., a button click).
    case event(String)

    /// Event for tracking when a screen is opened (e.g., a specific view or page).
    case screen(String)

    /// Event for tracking a user's identity or association with a company.
    case identify(String)

    // MARK: - Event Case Names

    /**
     Returns the constant name of the event case (e.g., "event", "screen", "identify").
     This is used to categorize events in a standardized way.
     */
    var caseName: String {
        switch self {
        case .event:
            return EventType.trackEvent
        case .screen:
            return EventType.screenEvent
        case .identify:
            return EventType.identifyCaseEvent
        }
    }

    // MARK: - Event Names

    /**
     Returns the event name, which can be either:
     - A custom event name for `event` cases.
     - A predefined constant for `screen` and `identify` cases.
     */
    var eventName: String {
        switch self {
        case .event:
            return EventType.trackEvent
        case .screen:
            return EventType.screenEvent
        case .identify:
            return EventType.identifyEvent
        }
    }

    // MARK: - Type Checking

    /// Checks if the event is a custom event (`event` case).
    var isEvent: Bool {
        return self.caseName == EventType.trackEvent
    }

    /// Checks if the event is related to a screen view (`screen` case).
    var isScreenEvent: Bool {
        return self.caseName == EventType.screenEvent
    }

    /// Checks if the event is an identification event (`identify` case).
    var isIdentifyEvent: Bool {
        return self.caseName == EventType.identifyCaseEvent
    }

    // MARK: - Associated Values

    /**
     Returns the user ID if the event is an `identify` event. If the event type is not `identify`, it returns `nil`.
     This is useful when determining the user associated with an identity-related event.
     */
    var userID: String? {
        if case let .identify(userID) = self {
            return userID
        } else {
            return nil
        }
    }

    /**
     Returns the screen name if the event is a `screen` event. If the event type is not `screen`, it returns `nil`.
     This helps in identifying the screen associated with a screen-view event.
     */
    var screenTitle: String? {
        if case let .screen(title) = self {
            return title
        } else {
            return nil
        }
    }

    /**
     Returns the screen name if the event is a `screen` event. If the event type is not `screen`, it returns `nil`.
     This helps in identifying the screen associated with a screen-view event.
     */
    var eventTitle: String? {
        if case let .event(title) = self {
            return title
        } else {
            return nil
        }
    }
}

internal extension EventType {

    // Static constants
    static var identifyEvent: String { return "user_identify" }
    static var identifyCaseEvent: String { return "identify" }
    static var screenEvent: String { return "screen" }
    static var trackEvent: String { return "track" }
}
