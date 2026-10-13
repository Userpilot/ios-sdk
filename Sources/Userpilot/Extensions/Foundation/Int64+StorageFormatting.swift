//
//  Int64+StorageFormatting.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Formats storage byte counts without changing the existing diagnostic output.
//

import Foundation

internal extension Int64 {
    /// Uses the same binary units and two decimal places as storage logs and statistics.
    var formattedStorageBytes: String {
        let kilobyte: Int64 = 1024
        let megabyte = kilobyte * 1024
        let gigabyte = megabyte * 1024
        switch self {
        case gigabyte...: return String(format: "%.2f GB", Double(self) / Double(gigabyte))
        case megabyte...: return String(format: "%.2f MB", Double(self) / Double(megabyte))
        case kilobyte...: return String(format: "%.2f KB", Double(self) / Double(kilobyte))
        default: return "\(self) B"
        }
    }
}
