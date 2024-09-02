//
//  Dictionary+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// Dictionary+Data contains extensions helper methods
//

import Foundation

extension Dictionary {
    /// Creates a dictionary by merging the given dictionary into this dictionary,
    /// preferring the new value for duplicate keys.
    func merging(_ other: [Key: Value]) -> [Key: Value] {
        self.merging(other) { _, new in new }
    }
}
