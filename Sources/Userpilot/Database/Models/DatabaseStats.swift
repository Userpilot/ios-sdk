//
//  DatabaseStats.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
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
        totalSizeBytes.formattedStorageBytes
    }

    var maxSizeFormatted: String {
        maxSizeBytes.formattedStorageBytes
    }

    var utilizationPercent: Int {
        guard maxSizeBytes > 0 else { return 0 }
        return Int((Double(totalSizeBytes) / Double(maxSizeBytes)) * 100.0)
    }

}
