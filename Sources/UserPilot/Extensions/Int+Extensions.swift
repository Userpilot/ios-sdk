//
//  Int+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 04/09/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `Int+Data` contains an extension with helper methods for the `Int` class.
//  This extension provides additional functionality to modify integer values easily.
//
//  Extensions include:
//  - `increment(by:)`: A method that increments the integer value by a specified amount, defaulting to 1.
//

import Foundation

extension Int {
    mutating func increment(by value: Int = 1) {
        self += value
    }
}
