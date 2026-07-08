//
//  TrackingUpdate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
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

        // Encode Payload ([String: Any]?) as JSON data
        if let properties = properties {
            let jsonData = try JSONSerialization.data(withJSONObject: properties, options: [])
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                try container.encode(jsonObject.mapValues { AnyCodable($0) }, forKey: .properties)
            }
        }

        if let company = company {
            let jsonData = try JSONSerialization.data(withJSONObject: company, options: [])
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                try container.encode(jsonObject.mapValues { AnyCodable($0) }, forKey: .company)
            }
        }

        // Auto-capture events must survive the offline round-trip: their batch
        // payload needs the screen context and the interaction event name.
        if let screen = screen {
            let jsonData = try JSONSerialization.data(withJSONObject: screen, options: [])
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                try container.encode(jsonObject.mapValues { AnyCodable($0) }, forKey: .screen)
            }
        }

        try container.encodeIfPresent(interactionEventName, forKey: .interactionEventName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EventType.self, forKey: .type)

        // Decode properties as [String: AnyCodable]? and convert to [String: Any]?
        if let propertiesDict = try container.decodeIfPresent(
            [String: AnyCodable].self, forKey: .properties) {
            properties = propertiesDict.mapValues { $0.value }
        } else {
            properties = nil
        }

        // Decode company as [String: AnyCodable]? and convert to [String: Any]?
        if let companyDict = try container.decodeIfPresent(
            [String: AnyCodable].self, forKey: .company) {
            company = companyDict.mapValues { $0.value }
        } else {
            company = nil
        }

        // Decode screen as [String: AnyCodable]? and convert to [String: Any]?
        if let screenDict = try container.decodeIfPresent(
            [String: AnyCodable].self, forKey: .screen) {
            screen = screenDict.mapValues { $0.value }
        } else {
            screen = nil
        }

        interactionEventName = try container.decodeIfPresent(
            String.self, forKey: .interactionEventName)
    }
}

extension Event {
    func toUser() -> User {
        return User(userId: userId ?? "",
                    properties: properties ?? [:],
                    company: company ?? [:])
    }
}
