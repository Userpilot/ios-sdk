//
//  TrackingUpdate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `Event` struct is a holder for event details in the Userpilot SDK.
//  It tracks information about various user actions, analytics events, and their associated metadata.
//

import Foundation

internal struct Event {

    // MARK: - Properties

    /// The type of event, described by the `EventType` enum.
    /// This determines the nature of the event (e.g., screen view, custom action).
    let type: EventType

    /// A dictionary of optional properties that provide additional
    /// metadata for the event (e.g., button clicked, item purchased).
    var properties: Payload = nil

    /// A dictionary of optional company-related properties. This can be
    /// used to track events related to specific organizations or entities.
    var company: Payload = nil

    /// A dictionary of optional properties that provide screen
    var screen: Payload = nil

    /// For automatic interaction capture (`mobile_autocapture`), the backend-facing interaction category
    /// (e.g. tap, text change). Sent on the track payload as `InteractionEventName` when present.
    var interactionEventName: String?

    // MARK: - Variables from `EventType`

    var caseName: String {
        return type.caseName
    }

    var eventName: String {
        return type.eventName
    }

    var eventTitle: String {
        return type.eventTitle ?? ""
    }

    var isEvent: Bool {
        return type.isEvent
    }

    var isIdentifyEvent: Bool {
        return type.isIdentifyEvent
    }

    var screenTitle: String? {
        return type.screenTitle
    }

    var userId: String? {
        return type.userId
    }

    var userpilotAnalytic: UserpilotAnalytic {
        switch type {
        case .identify:
            return .identify
        case .screen:
            return .screen
        case .event, .autoCaptureEvent:
            return .event
        }
    }
}

internal extension Event {
    func toUser() -> User {
        return User(userId: userId ?? "",
                    properties: properties ?? [:],
                    company: company ?? [:])
    }
}
