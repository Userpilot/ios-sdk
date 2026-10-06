//
//  Event.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Represents an analytics event and metadata used by publishing and offline storage.
//

import Foundation

/// Analytics event plus optional metadata used by publishing and offline storage.
internal struct Event {

    // MARK: - Properties

    /// Event kind.
    let type: EventType

    /// Event metadata.
    var properties: Payload = nil

    /// Company metadata.
    var company: Payload = nil

    /// Screen metadata used by auto-capture.
    var screen: Payload = nil

    /// Auto-capture interaction category sent as `InteractionEventName`.
    var interactionEventName: String?

    /// Queue-only reload metadata for SDK-generated screens; nil for app screen events.
    var isFakeReload: Bool?

    // MARK: - EventType helpers

    var isIdentifyEvent: Bool {
        return type.isIdentifyEvent
    }

    var isScreenEvent: Bool {
        return type.isScreenEvent
    }

    var isTrackEvent: Bool {
        return type.isTrackEvent
    }

    var eventName: String {
        return type.eventName
    }

    var eventTitle: String {
        return type.eventTitle ?? ""
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

// MARK: - Codable Conformance

extension Event: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case company
        case screen
        case interactionEventName = "interaction_event_name"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        try container.encodePayloadIfPresent(properties, forKey: .properties)
        try container.encodePayloadIfPresent(company, forKey: .company)
        // Preserve autocapture screen context and interaction name across the offline round-trip.
        try container.encodePayloadIfPresent(screen, forKey: .screen)

        try container.encodeIfPresent(interactionEventName, forKey: .interactionEventName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EventType.self, forKey: .type)

        properties = try container.decodeIfPresent(
            [String: AnyCodable].self, forKey: .properties)?.mapValues { $0.value }
        company = try container.decodeIfPresent([String: AnyCodable].self, forKey: .company)?.mapValues { $0.value }
        screen = try container.decodeIfPresent([String: AnyCodable].self, forKey: .screen)?.mapValues { $0.value }

        interactionEventName = try container.decodeIfPresent(
            String.self, forKey: .interactionEventName)
    }
}

extension Event {
    /**
     * Stable key for event throttling.
     * Non-AutoCapture events use `eventTitle`, or `eventName` when
     * the title is empty; autocapture uses screen + interaction/tab context.
     */
    func trackEventThrottleKey() -> String {
        guard case .autoCaptureEvent = type else {
            return eventTitle.isEmpty ? eventName : eventTitle
        }

        let properties = properties ?? [:]
        func property(_ key: String) -> String {
            return Self.throttleString(from: properties[key])
        }

        let rawInteraction = property(Constants.AutoCapture.rawInteractionType)

        return [
            throttleScreenName,
            eventName,
            rawInteraction.isEmpty ? (interactionEventName ?? "") : rawInteraction,
            property(Constants.AutoCapture.tabName),
            property(Constants.AutoCapture.tabIndex),
            property(Constants.AutoCapture.hierarchy),
            property(Constants.AutoCapture.accessibilityIdentifier),
            property(Constants.AutoCapture.dialogTitle),
            property(Constants.AutoCapture.targetText),
            property(Constants.AutoCapture.section),
            property(Constants.AutoCapture.selectedIndex),
            property(Constants.AutoCapture.selectedValue),
            property(Constants.AutoCapture.placeholder),
            property(Constants.AutoCapture.accessibilityLabel)
        ].joined(separator: "|")
    }

    /// Resolves a display class from the screen context captured with an autocapture event.
    private var throttleScreenName: String {
        guard let screen, !screen.isEmpty else { return "" }

        let keys = [
            Constants.AutoCapture.screenClass,
            Constants.AutoCapture.screenTitle,
            Constants.AutoCapture.screenName
        ]
        for key in keys {
            if let name = screen[key] as? String, !name.isEmpty {
                return name
            }
        }
        return ""
    }

    private static func throttleString(from value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    func toUser() -> User {
        return User(userId: userId ?? "",
                    properties: properties ?? [:],
                    company: company ?? [:])
    }

    /// Converts accepted identify data without changing the publisher's identity or session state.
    func identifyPayload() -> [String: Any] {
        var payload: [String: Any] = [Constants.Analytics.metaDataProperty: properties ?? [:]]
        if let company, !company.isEmpty {
            payload[Constants.Analytics.identifyCompanyProperty] = company
        }
        return payload
    }

    /// Builds custom-event or autocapture fields after the publisher has checked screen eligibility.
    func trackPayload() -> [String: Any] {
        var payload: [String: Any] = [Constants.Analytics.metaDataProperty: properties ?? [:]]
        payload[Constants.Analytics.eventNameProperty] = type == .autoCaptureEvent
            ? interactionEventName : eventTitle
        if let screen { payload[Constants.Analytics.screenProperty] = screen }
        return payload
    }
}

private extension KeyedEncodingContainer {
    /// Offline payloads must first pass Foundation's JSON validation and numeric bridging.
    /// Encoding AnyCodable directly would silently turn unsupported values into null instead of rejecting the event.
    mutating func encodePayloadIfPresent(_ payload: Payload, forKey key: Key) throws {
        guard let payload else { return }
        // Foundation raises an Objective-C exception for non-JSON objects/nonfinite numbers.
        // Reject them as a Swift encoding error so the existing offline error handling can recover.
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw EncodingError.invalidValue(payload, .init(
                codingPath: codingPath + [key],
                debugDescription: "Event payload must contain valid JSON values"
            ))
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let normalized = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try encode(normalized.mapValues { AnyCodable($0) }, forKey: key)
    }
}
