//
//  EventType.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Defines analytics event kinds and the names sent to the backend.
//

/// Type-safe analytics event kinds and their wire names.
internal enum EventType: Equatable {

    /// Custom track event.
    case event(String)

    /// Auto-captured interaction event.
    case autoCaptureEvent

    /// Screen view event.
    case screen(String)

    /// Identify event.
    case identify(String)

    /// Socket/database event name for this type.
    var eventName: String {
        switch self {
        case .event:
            return Constants.Event.trackEvent
        case .autoCaptureEvent:
            return Constants.Event.autoCaptureEvent
        case .screen:
            return Constants.Event.screenEvent
        case .identify:
            return Constants.Event.identifyEvent
        }
    }

    /// Public callback category; custom and autocaptured interactions are both track events.
    var userpilotAnalytic: UserpilotAnalytic {
        switch self {
        case .identify:
            return .identify
        case .screen:
            return .screen
        case .event, .autoCaptureEvent:
            return .event
        }
    }

    // MARK: - Type Checking

    /// True only for custom track events.
    var isEvent: Bool {
        if case .event = self {
            return true
        }
        return false
    }

    /// True only for auto-captured interaction events.
    var isAutoCaptureEvent: Bool {
        if case .autoCaptureEvent = self {
            return true
        }
        return false
    }

    /// True for identify events.
    var isIdentifyEvent: Bool {
        if case .identify = self {
            return true
        }
        return false
    }

    /// True for screen events.
    var isScreenEvent: Bool {
        if case .screen = self {
            return true
        }
        return false
    }

    /// True for events that use the track pipeline.
    var isTrackEvent: Bool {
        return isEvent || isAutoCaptureEvent
    }

    // MARK: - Associated Values

    /// User id carried by identify events.
    var userId: String? {
        if case let .identify(userId) = self {
            return userId
        } else {
            return nil
        }
    }

    /// Screen title carried by screen events.
    var screenTitle: String? {
        if case let .screen(title) = self {
            return title
        } else {
            return nil
        }
    }

    /// Event title carried by custom track events.
    var eventTitle: String? {
        if case let .event(title) = self {
            return title
        } else {
            return nil
        }
    }
}

// MARK: - Codable Conformance

extension EventType: Codable {

    /// Coding keys for the persisted offline-storage representation.
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)

        switch type {
        case Constants.Event.trackEvent:
            self = .event(value)
        case Constants.Event.autoCaptureEvent:
            self = .autoCaptureEvent
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventName, forKey: .type)
        switch self {
        case .event(let value), .screen(let value), .identify(let value):
            try container.encode(value, forKey: .value)
        case .autoCaptureEvent:
            try container.encode("", forKey: .value)
        }
    }
}
