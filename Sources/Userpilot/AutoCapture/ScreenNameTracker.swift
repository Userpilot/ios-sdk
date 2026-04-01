//
//  ScreenNameTracker.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  ScreenNameTracker manages screen navigation state and tab selection tracking
//  for automatic analytics capture.
//

import Foundation

// MARK: - Screen Name Tracking Protocol

/// `ScreenNameTracking` defines the interface for tracking screen navigation and tab states.
internal protocol ScreenNameTracking: AnyObject {
    /// Updates the current screen with full payload
    /// - Parameter payload: The screen tracking payload
    func updateScreen(with payload: ScreenTrackingPayload)

    /// Returns the current screen tracking payload
    /// - Returns: The current screen payload or nil
    func getCurrentPayload() -> ScreenTrackingPayload?

    /// Builds a screen context dictionary for event properties
    /// - Returns: Dictionary with current_screen, screen_class, screen_type, previous_screen, etc.
    func buildScreenDictionary() -> [String: Any]

    /// Builds a screen context dictionary for auto event properties
    func buildScreenDictionaryForEvent() -> [String: Any]

    /// Resets all tracked state to initial values
    func reset()
}

// MARK: - Screen Name Tracker

/// `ScreenNameTracker` implements screen and tab state tracking for analytics.
internal final class ScreenNameTracker: ScreenNameTracking {
    // MARK: - Properties

    /// Associated object key for storing untracked screen flags
    internal static var untrackedScreenKey: UInt8 = 0

    /// The current screen tracking payload
    private var currentPayload: ScreenTrackingPayload?

    // MARK: - Initialization

    /// Creates a new screen name tracker
    /// - Parameter container: Dependency injection container
    init(container: DIContainer) {
        _ = container
    }

    // MARK: - ScreenNameTracking Protocol

    /// Updates the current screen with full payload
    /// - Parameter payload: The screen tracking payload
    func updateScreen(with payload: ScreenTrackingPayload) {
        currentPayload = payload
    }

    /// Returns the current screen tracking payload
    /// - Returns: The current screen payload or nil
    func getCurrentPayload() -> ScreenTrackingPayload? {
        return currentPayload
    }

    /// Builds a screen context dictionary from the current payload for event properties
    func buildScreenDictionary() -> [String: Any] {
        guard let payload = currentPayload else {
            return [:]
        }

        var screen: [String: Any] = [
            AutoCaptureConstants.screenName: payload.currentScreen,
            AutoCaptureConstants.screenClass: payload.screenClass,
            AutoCaptureConstants.screenType: payload.screenType
        ]

        if let navTitle = payload.navigationTitle {
            screen[AutoCaptureConstants.navigationTitle] = navTitle
        }
        if let vcAccessibilityIdentifier = payload.vcAccessibilityIdentifier {
            screen[AutoCaptureConstants.vcAccessibilityIdentifier] = vcAccessibilityIdentifier
        }
        if let vcAccessibilityLabel = payload.vcAccessibilityLabel {
            screen[AutoCaptureConstants.vcAccessibilityLabel] = vcAccessibilityLabel
        }

        return screen
    }

    /// Builds a screen context dictionary from the current payload for event properties
    func buildScreenDictionaryForEvent() -> [String: Any] {
        guard let payload = currentPayload else {
            return [:]
        }

        var screen: [String: Any] = [
            AutoCaptureConstants.screenTitle: payload.screenClass
        ]

        return screen
    }

    /// Resets all tracked state to initial values
    func reset() {
        currentPayload = nil
    }
}
