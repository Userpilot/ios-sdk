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
