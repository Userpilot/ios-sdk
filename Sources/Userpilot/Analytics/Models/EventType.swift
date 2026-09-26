//
//  EventType.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//

import Foundation

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
            return EventType.trackEvent
        case .autoCaptureEvent:
            return EventType.trackAutoCaptureEvent
        case .screen:
            return EventType.screenEvent
        case .identify:
            return EventType.identifyEvent
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

extension EventType {

    // Wire values are defined once in `Constants.Event`; these are internal aliases
    // for the `eventName` mapping above.
    static let identifyEvent = Constants.Event.identifyEvent
    static let screenEvent = Constants.Event.screenEvent
    private static let trackEvent = Constants.Event.trackEvent
    private static let trackAutoCaptureEvent = Constants.Event.autoCaptureEvent
}

// MARK: - Codable Conformance

extension EventType: Codable {

    /// Coding keys for the persisted offline-storage representation.
    enum CodingKeys: String, CodingKey {
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
        switch self {
        case .event(let eventName):
            try container.encode(Constants.Event.trackEvent, forKey: .type)
            try container.encode(eventName, forKey: .value)
        case .autoCaptureEvent:
            try container.encode(Constants.Event.autoCaptureEvent, forKey: .type)
            try container.encode("", forKey: .value)
        case .screen(let screenTitle):
            try container.encode(Constants.Event.screenEvent, forKey: .type)
            try container.encode(screenTitle, forKey: .value)
        case .identify(let userId):
            try container.encode(Constants.Event.identifyEvent, forKey: .type)
            try container.encode(userId, forKey: .value)
        }
    }
}
