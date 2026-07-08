//
//  Dictionary+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `Dictionary+Extension` contains extensions with helper methods for the `Dictionary` class.
//

import Foundation

internal extension Dictionary {
    /// Creates a dictionary by merging the given dictionary into this dictionary,
    /// preferring the new value for duplicate keys.
    func merging(_ other: [Key: Value]) -> [Key: Value] {
        self.merging(other) { _, new in new }
    }

    func toJSONString() -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .withoutEscapingSlashes)
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            print("Error converting dictionary to JSON: \(error.localizedDescription)")
            return nil
        }
    }
}

internal extension Dictionary where Key == String, Value == Any {
    /// Returns true when the dictionary contains `key` and its value matches `expectedValue`.
    func hasPropertyValue(_ key: String, expectedValue: Any) -> Bool {
        guard let value = self[key] else { return false }

        if let expectedString = expectedValue as? String {
            return value as? String == expectedString
        }

        if let expectedBool = expectedValue as? Bool {
            if let bool = value as? Bool {
                return bool == expectedBool
            }
            if let number = value as? NSNumber {
                return number.boolValue == expectedBool
            }
        }

        return false
    }
}
