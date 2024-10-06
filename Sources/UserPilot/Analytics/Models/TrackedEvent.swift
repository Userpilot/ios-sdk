//
//  TrackedEvent.swift
//
//
//  Created by Motasem Hamed on 04/09/2024.
//

import Foundation

/// Represents a payload for tracking events in the system.
///
/// This struct encapsulates the action type and a list of events to be tracked.
/// The `act` property is a constant string that identifies the action type as "track".
internal struct TrackedPayload {
    /// The action type for the payload, which is "track".
    let act: String = "track"

    /// A list of `TrackedPayloadEvent` instances that represent the events to be tracked.
    let events: [TrackedPayloadEvent]

    /// Converts the `TrackedPayload` instance to a dictionary representation.
    ///
    /// This method maps the payload properties into a dictionary format, including the
    /// action type and a list of events. Each event is also converted to a dictionary.
    ///
    /// - Returns: A dictionary with the payload's properties.
    func toDictionary() -> [String: Any] {
        // Convert each event to a dictionary
        let eventsDict = events.map { $0.toDictionary() }

        // Return the payload as a dictionary
        return [
            "act": act,
            "events": eventsDict
        ]
    }
}

/// Represents an individual event within the tracked payload.
///
/// This struct includes the event's title and optional metadata that can be associated
/// with the event.
internal struct TrackedPayloadEvent {
    /// The title of the event.
    let title: String

    /// Optional additional metadata associated with the event.
    /// This is a dictionary where keys are strings and values are of any type.
    let meta: [String: Any]?

    /// Converts the `TrackedPayloadEvent` instance to a dictionary representation.
    ///
    /// This method maps the event properties into a dictionary format. If the optional
    /// metadata is provided, it will be included in the dictionary.
    ///
    /// - Returns: A dictionary with the event's properties.
    func toDictionary() -> [String: Any] {
        // Start with a dictionary containing the title
        var dict: [String: Any] = ["title": title]

        // Add metadata to the dictionary if it exists
        if let meta = meta {
            dict["meta"] = meta
        }

        // Return the event as a dictionary
        return dict
    }
}
