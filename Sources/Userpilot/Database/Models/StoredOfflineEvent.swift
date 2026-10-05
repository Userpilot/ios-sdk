//
//  StoredOfflineEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/09/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Stable JSON payload stored inside the offline events database.
//  Mirrors the Android `StoredOfflineEvent` so both platforms replay the same batch shape.
//

import Foundation

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
        // Required, not defaulted: every writer sets it, so a row without one is corrupt and
        // must not be silently filed as analytics. Matches the Android envelope.
        kind = try container.decode(StoredOfflineEventKind.self, forKey: .kind)
        eventType = try container.decode(String.self, forKey: .eventType)
        event = try container.decodeIfPresent(Event.self, forKey: .event)

        if let payloadDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .payload) {
            payload = payloadDict.mapValues { $0.value }
        } else {
            payload = nil
        }
    }
}

// MARK: - Offline replay

extension StoredOfflineEvent {

    /// Builds one `batch_events` entry without changing the stored envelope or its schema.
    func toBatchPayload(createdAt: TimeInterval) -> [String: Any]? {
        guard isSupportedSchema else { return nil }
        var data: [String: Any] = [
            Constants.OfflineEvents.eventTypeProperty: eventType,
            Constants.OfflineEvents.createdAtProperty: formatTimestampWithTimezone(createdAt)
        ]
        if isInternalEvent {
            // Internal payloads stay flat, including their existing collision precedence.
            for (key, value) in payload ?? [:] { data[key] = value }
            return data
        }
        guard let event else { return nil }
        data[Constants.OfflineEvents.eventTypeProperty] = event.eventName
        data[Constants.Analytics.metaDataProperty] = event.properties ?? [:]
        switch event.type {
        case .identify:
            if let company = event.company, !company.isEmpty {
                data[Constants.Analytics.identifyCompanyProperty] = company
            }
        case .screen:
            data[Constants.Analytics.screenTitleProperty] = event.screenTitle ?? ""
            var metadata = event.properties ?? [:]
            metadata[Constants.Analytics.fakeReload] = false
            data[Constants.Analytics.metaDataProperty] = metadata
        case .event, .autoCaptureEvent:
            data[Constants.Analytics.eventNameProperty] = event.interactionEventName ?? event.eventTitle
            if let screen = event.screen { data[Constants.Analytics.screenProperty] = screen }
        }
        return data
    }

    /// Keep the existing UTC ISO-8601 representation; each call owns its formatter.
    private func formatTimestampWithTimezone(_ timestampMillis: TimeInterval) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: timestampMillis / 1_000.0))
    }
}
