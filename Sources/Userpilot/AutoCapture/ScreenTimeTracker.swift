//
//  ScreenTimeTracker.swift
//  Userpilot
//
//  Created by Motasem Hamed on 05/03/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  ScreenTimeTracker tracks foreground-only time spent on each screen for analytics.
//  SessionMonitor calls onAppForeground and onAppBackground; auto-capture calls onScreenChanged.
//

import Foundation

// MARK: - Screen Time Tracking Protocol

/// Protocol for tracking foreground-only time spent per screen.
/// Used by SessionMonitor (onAppForeground/onAppBackground) and auto-capture (onScreenChanged).
internal protocol ScreenTimeTracking: AnyObject {

    /// Called when the app enters the foreground. Records the timestamp for the next foreground segment.
    func onAppForeground()

    /// Called when the app enters the background. Adds elapsed foreground time since last resume to the current screen.
    func onAppBackground()

    /// Called when the user navigates to a new screen.
    /// - Parameter payload: The new screen being shown.
    /// - Returns: Time in ms spent on the previous screen (foreground only), or nil for the first screen.
    func onScreenChanged(_ payload: ScreenTrackingPayload) -> Int?

    /// Resets all tracked state.
    func reset()
}

// MARK: - Screen Time Tracker

/// Tracks foreground-only time spent on each screen for analytics.
/// Does not observe app lifecycle directly; SessionMonitor calls onAppForeground and onAppBackground.
internal final class ScreenTimeTracker: ScreenTimeTracking {

    /// Current screen payload (identity for "which screen we're on"); we only need to know if we had a previous screen.
    private var currentScreen: ScreenTrackingPayload?

    /// Monotonic time (seconds) when the app last entered the foreground.
    private var lastForegroundResumeAt: TimeInterval = 0

    /// Accumulated foreground time (seconds) for the current screen.
    private var foregroundAccumulatedSeconds: TimeInterval = 0

    private var hasEverResumedForeground: Bool {
        lastForegroundResumeAt > 0
    }

    // MARK: - Initialization

    init(container: DIContainer) {
        _ = container
    }

    // MARK: - ScreenTimeTracking

    func onAppForeground() {
        lastForegroundResumeAt = ProcessInfo.processInfo.systemUptime
    }

    func onAppBackground() {
        if hasEverResumedForeground {
            let now = ProcessInfo.processInfo.systemUptime
            foregroundAccumulatedSeconds += (now - lastForegroundResumeAt)
        }
    }

    func onScreenChanged(_ payload: ScreenTrackingPayload) -> Int? {
        let now = ProcessInfo.processInfo.systemUptime
        let previousDurationMs: Int?
        if currentScreen != nil {
            let segment = hasEverResumedForeground ? (now - lastForegroundResumeAt) : 0
            let totalSeconds = foregroundAccumulatedSeconds + segment
            previousDurationMs = Int(max(0, totalSeconds) * 1000)
        } else {
            previousDurationMs = nil
        }

        currentScreen = payload
        foregroundAccumulatedSeconds = 0
        lastForegroundResumeAt = now

        return previousDurationMs
    }

    func reset() {
        currentScreen = nil
        lastForegroundResumeAt = 0
        foregroundAccumulatedSeconds = 0
    }
}
