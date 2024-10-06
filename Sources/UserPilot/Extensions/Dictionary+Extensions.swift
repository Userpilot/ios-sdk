//
//  Dictionary+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `Dictionary+Data` contains extensions with helper methods for the `Dictionary` class.
//  These methods provide additional functionality for merging dictionaries and converting
//  dictionaries to JSON strings.
//
//  Extensions include:
//  - `merging(_:)`: Merges another dictionary into the current dictionary, preferring the new values
// for duplicate keys.
//  - `toJSONString()`: Converts the dictionary to a JSON string representation.
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
            // swiftlint:disable:next non_optional_string_data_conversion
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            print("Error converting dictionary to JSON: \(error.localizedDescription)")
            return nil
        }
    }
}
