//
//  EventType.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `EventType` enum represents different types of events that can be tracked in the Userpilot SDK.
//  These include custom events, screen views, and user identity grouping.
//

import Foundation

/// The `EventType` enum is used to categorize and manage different types of events within the Userpilot SDK.
///
/// It defines three types of events:
/// - `event`: Tracks custom events, such as button clicks or other user interactions.
/// - `screen`: Tracks screen views, logging when a particular screen is opened.
/// - `identify`: Tracks a user being identified, either as part of a company or based on their unique ID.
///
/// The enum also provides utility methods to retrieve metadata (such as event name and user ID) and check event types.
internal enum EventType: Equatable, Codable {

    /// Custom event for tracking a user action (e.g., a button click).
    case event(String)

    /// Event for tracking when a screen is opened (e.g., a specific view or page).
    case screen(String)

    /// Event for tracking a user's identity or association with a company.
    case identify(String)

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)

        switch type {
        case Constants.Event.trackEvent:
            self = .event(value)
        case Constants.Event.screenEvent:
            self = .screen(value)
        case Constants.Event.identifyEvent:
            self = .identify(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown event type: \(type)"
            )
        }
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .event(let eventName):
            try container.encode(Constants.Event.trackEvent, forKey: .type)
            try container.encode(eventName, forKey: .value)
        case .screen(let screenTitle):
            try container.encode(Constants.Event.screenEvent, forKey: .type)
            try container.encode(screenTitle, forKey: .value)
        case .identify(let userId):
            try container.encode(Constants.Event.identifyEvent, forKey: .type)
            try container.encode(userId, forKey: .value)
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
            return Constants.Event.trackEvent
        case .screen:
            return Constants.Event.screenEvent
        case .identify:
            return Constants.Event.identifyEvent
        }
    }

    // MARK: - Type Checking

    /// Checks if the event is an identification event (`identify` case).
    var isIdentifyEvent: Bool {
        return self.eventName == Constants.Event.identifyEvent
    }

    /// Checks if the event is related to a screen view (`screen` case).
    var isScreenEvent: Bool {
        return self.eventName == Constants.Event.screenEvent
    }

    /// Checks if the event is an track event (`track` case).
    var isTrackEvent: Bool {
        return self.eventName == Constants.Event.trackEvent
    }

    // MARK: - Associated Values

    /**
     Returns the user Id if the event is an `identify` event. If the event type is not `identify`, it returns `nil`.
     This is useful when determining the user associated with an identity-related event.
     */
    var userId: String? {
        if case let .identify(userId) = self {
            return userId
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
