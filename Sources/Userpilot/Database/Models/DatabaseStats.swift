//
//  DatabaseStats.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Holds storage statistics for monitoring event database state including count,
//  size, limits, and utilization percentage.
//

import Foundation

internal struct DatabaseStats {
    let eventCount: Int
    let totalSizeBytes: Int64
    let maxEventCount: Int
    let maxSizeBytes: Int64
    let isCountLimitReached: Bool
    let isSizeLimitReached: Bool

    var totalSizeFormatted: String {
        formatBytes(totalSizeBytes)
    }

    var maxSizeFormatted: String {
        formatBytes(maxSizeBytes)
    }

    var utilizationPercent: Int {
        guard maxSizeBytes > 0 else { return 0 }
        return Int((Double(totalSizeBytes) / Double(maxSizeBytes)) * 100.0)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let bytesInKilobyte: Int64 = 1024
        let bytesInMegabyte = bytesInKilobyte * 1024
        let bytesInGigabyte = bytesInMegabyte * 1024

        switch bytes {
        case bytesInGigabyte...:
            return String(format: "%.2f GB", Double(bytes) / Double(bytesInGigabyte))
        case bytesInMegabyte...:
            return String(format: "%.2f MB", Double(bytes) / Double(bytesInMegabyte))
        case bytesInKilobyte...:
            return String(format: "%.2f KB", Double(bytes) / Double(bytesInKilobyte))
        default:
            return "\(bytes) B"
        }
    }
}
