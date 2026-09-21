//
//  StoredOfflineEvent.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Stable JSON payload stored inside the offline events database.
//  Mirrors the Android `StoredOfflineEvent` so both platforms replay the same batch shape.
//

import Foundation

/// Which pipeline a stored offline row came from.
internal enum StoredOfflineEventKind: String, Codable {
    case analytics
    /// `internal` is a Swift keyword, so the case is spelled differently from its raw value.
    case internalEvent = "internal"
}

/// The envelope persisted inside `EventStorage.data`.
///
/// An analytics row nests the existing `Codable` `Event`; an internal row carries the SDK
/// event's flat payload. The discriminator lives here rather than in a stored column so no
/// database schema change is needed.
internal struct StoredOfflineEvent {
    static let schemaVersionValue = 1

    let schemaVersion: Int
    let kind: StoredOfflineEventKind
    let eventType: String
    let event: Event?
    let payload: [String: Any]?

    var isInternalEvent: Bool { kind == .internalEvent }

    var isSupportedSchema: Bool { schemaVersion == Self.schemaVersionValue }

    init(event: Event) {
        self.schemaVersion = Self.schemaVersionValue
        self.kind = .analytics
        self.eventType = event.eventName
        self.event = event
        self.payload = nil
    }

    init(sdkEvent: SDKEvent) {
        self.schemaVersion = Self.schemaVersionValue
        self.kind = .internalEvent
        self.eventType = sdkEvent.eventName
        self.event = nil
        self.payload = sdkEvent.eventPayload
    }
}

// MARK: - Codable Conformance

extension StoredOfflineEvent: Codable {

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case kind
        case eventType = "event_type"
        case event
        case payload
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(kind, forKey: .kind)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(event, forKey: .event)

        // Encoded directly rather than through a JSONSerialization round-trip: that round-trip
        // turns Bool into __NSCFBoolean, which AnyCodable matches as Int and writes out as 0/1.
        if let payload = payload {
            try container.encode(payload.mapValues { AnyCodable($0) }, forKey: .payload)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.schemaVersionValue
        kind = try container.decodeIfPresent(StoredOfflineEventKind.self, forKey: .kind) ?? .analytics
        eventType = try container.decode(String.self, forKey: .eventType)
        event = try container.decodeIfPresent(Event.self, forKey: .event)

        if let payloadDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .payload) {
            payload = payloadDict.mapValues { $0.value }
        } else {
            payload = nil
        }
    }
}
