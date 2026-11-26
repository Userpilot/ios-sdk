//
//  KeyedEncodingContainer+EventPayload.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Validates and normalizes offline event JSON before Codable encoding.
//

import Foundation

internal extension KeyedEncodingContainer {
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
