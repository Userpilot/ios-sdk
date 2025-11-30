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

    // MARK: - Variables from `EventType`

    var eventName: String {
        return type.eventName
    }

    var eventTitle: String {
        return type.eventTitle ?? ""
    }

    var isIdentifyEvent: Bool {
        return type.isIdentifyEvent
    }

    var isScreenEvent: Bool {
        return type.isScreenEvent
    }

    var isTrackEvent: Bool {
        return type.isTrackEvent
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
        case .event:
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
    }
}

// MARK: - User Conversion

extension Event {
    func toUser() -> User {
        return User(
            userId: userId ?? "",
            properties: properties ?? [:],
            company: company ?? [:])
    }
}
