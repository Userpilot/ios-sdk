//
//  Constants+Database.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Offline event storage limits and database schema version.
//

import Foundation

extension Constants {

    /// Local offline event database limits and schema.
    enum Database {
        static let maxEventCount = 5_000
        static let maxSizeBytes: Int64 = 3 * 1024 * 1024
        /// Bump when the Events table schema changes; add migration in `EventDatabaseStorage`.
        static let schemaVersion: Int32 = 1
    }
}
