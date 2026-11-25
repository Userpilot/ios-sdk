//
//  KeyedEncodingContainer+DynamicKeys.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Encodes supported API property types and formats their coding paths.
//

import Foundation

internal extension KeyedEncodingContainer where K == DynamicCodingKeys {

    /// Encodes the given dictionary to primitive types permitted by the Userpilot API, skipping invalid types.
    mutating func encodeSkippingInvalid(_ dict: Payload) throws {
        var encodingErrorKeys: [String] = []

        try dict?.forEach { key, value in
            let codingKey = DynamicCodingKeys(key: key)
            switch value {
            case let string as String:
                try self.encode(string, forKey: codingKey)
            case let url as URL:
                try self.encode(url.absoluteString, forKey: codingKey)
            // swiftlint:disable:next legacy_objc_type
            case let number as NSNumber:
                if isBoolNumber(number), let bool = number as? Bool {
                    try self.encode(bool, forKey: codingKey)
                } else {
                    try self.encode(number.decimalValue, forKey: codingKey)
                }
            case let bool as Bool:
                try self.encode(bool, forKey: codingKey)
            case let date as Date:
                try self.encode(date, forKey: codingKey)
            default:
                encodingErrorKeys.append(codingKey.stringValue)
            }
        }

        if !encodingErrorKeys.isEmpty {
            print(
                """
                Unsupported value(s) included in %{public}@ when encoding key(s): %{public}@.
                These keys have been omitted. Only String, Number, Date, URL and Bool types allowed.
                """,
                self.codingPath.pretty,
                encodingErrorKeys.sorted().description
            )
        }
    }

    // helper to determine if an NSNumber is actually containing a Boolean value
    // swiftlint:disable:next legacy_objc_type
    private func isBoolNumber(_ num: NSNumber) -> Bool {
        let boolID = CFBooleanGetTypeID() // the type Id of CFBoolean
        let numID = CFGetTypeID(num) // the type ID of num
        return numID == boolID
    }
}

internal extension CodingKey {
    var pretty: String {
        if let intValue {
            return "\(intValue)"
        }

        return stringValue
    }
}
internal extension Array where Element == CodingKey {
    var pretty: String {
        String(self
            .map { $0.pretty }
            .joined(separator: "."))
    }
}
