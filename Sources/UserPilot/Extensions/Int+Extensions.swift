//
//  Int+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 04/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `Int+Data` contains an extension with helper methods for the `Int` class.
//  This extension provides additional functionality to modify integer values easily.
//
//  Extensions include:
//  - `increment(by:)`: A method that increments the integer value by a specified amount, defaulting to 1.
//

import Foundation

internal extension Int {
    mutating func increment(by value: Int = 1) {
        self += value
    }
}

internal extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

internal extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
