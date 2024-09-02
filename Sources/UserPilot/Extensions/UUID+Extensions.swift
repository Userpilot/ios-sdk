//
//  UUID+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// UUID+Data contains extensions helper methods
//

import Foundation

// Allows overriding of UUID creation for deterministic testing.
extension UUID {

    static var generator: () -> UUID = UUID.init

    var userpilotFormatted: String {
        return uuidString.lowercased()
    }

    static func create() -> UUID {
        return UUID.generator()
    }

}
