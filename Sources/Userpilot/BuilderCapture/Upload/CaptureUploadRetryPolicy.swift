//
//  CaptureUploadRetryPolicy.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Decides whether a failed capture upload attempt is retried within its run, and after how long.
//

import Foundation

/// One upload run: at most `maxAttempts` attempts with the same bytes and capture id. Pure; the
/// coordinator owns the timer and the attempt counter.
internal enum CaptureUploadRetryPolicy {
    static let maxAttempts = 4
    /// The wait after a `transient` failure on attempt 1, 2 or 3.
    static let transientDelays: [TimeInterval] = [2, 4, 8]
    /// The wait after the run's first `throttled` failure; a second one ends the run.
    static let throttleDelay: TimeInterval = 10

    /// The wait before the next attempt, or nil when the run stops and the failure's alert shows.
    ///
    /// - Parameters:
    ///   - error: the failure of the attempt that just finished.
    ///   - attempt: that attempt's 1-based number in the run.
    ///   - throttledAlready: whether an earlier attempt in this run was already throttled.
    static func nextDelay(after error: CaptureUploadError, attempt: Int, throttledAlready: Bool) -> TimeInterval? {
        guard attempt < maxAttempts else { return nil }
        switch error {
        case .transient:
            return transientDelays.indices.contains(attempt - 1) ? transientDelays[attempt - 1] : nil
        case .throttled:
            return throttledAlready ? nil : throttleDelay
        case .invalidToken, .sessionExpired, .tooLarge, .rejected, .cancelled:
            return nil
        }
    }
}
