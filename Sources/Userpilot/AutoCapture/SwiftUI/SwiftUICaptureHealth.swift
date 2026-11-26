//
//  SwiftUICaptureHealth.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Stops native title scans for the process when SwiftUI render structures are not recognized.
//

import Foundation

/// Any-thread process health. The lock owns both counters; native scans and logging stay outside it.
internal enum SwiftUICaptureHealth {

    /// Consecutive structurally failed scans before capture turns off.
    static let tripThreshold = 3

    private static let lock = NSLock()
    private static var consecutiveFailures = 0
    private static var tripped = false

    static var isTripped: Bool {
        lock.withLock { tripped }
    }

    /// Records one scan and returns true when this scan tripped the breaker.
    ///
    /// A scan is a structural failure when it saw hosting views but located no
    /// display list in any of them, or found text items that paired with no
    /// drawing layer. A screen that simply has no text is not a failure.
    @discardableResult
    static func recordScan(hosts: Int, locatedLists: Int, textItems: Int, pairedEntries: Int) -> Bool {
        guard hosts > 0 else { return false }
        let failed = locatedLists == 0 || (textItems > 0 && pairedEntries == 0)

        return lock.withLock {
            guard !tripped else { return false }
            guard failed else {
                consecutiveFailures = 0
                return false
            }
            consecutiveFailures += 1
            tripped = consecutiveFailures >= tripThreshold
            return tripped
        }
    }

    #if DEBUG
    // swiftlint:disable:next identifier_name
    static func _resetForTesting() {
        lock.withLock {
            consecutiveFailures = 0
            tripped = false
        }
    }
    #endif
}
