//
//  UUID+Data.swift
//  UserPilot SDK
//
//  UUID+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//
//  [Brief Description]
//  This file contains an extension for the `UUID` class, providing helper methods
//  to customize UUID generation and formatting. It includes a method to override UUID creation
//  for testing purposes and a method to format UUID strings.
//
//  Extensions include:
//  - `generator`: A closure that generates UUIDs, allowing for customizable UUID creation.
//  - `userpilotFormatted`: Returns the UUID string in lowercase for consistent formatting.
//  - `create()`: Generates a new UUID using the `generator` closure.
//

import Foundation

// Allows overriding of UUID creation for deterministic testing.
internal extension UUID {

    static var generator: () -> UUID = UUID.init

    var userpilotFormatted: String {
        return uuidString.lowercased()
    }

    static func create() -> UUID {
        return UUID.generator()
    }

}
