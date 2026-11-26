//
//  ScreenNameTracker.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  ScreenNameTracker retains one screen snapshot for analytics and autocapture.
//  ScreenTrackingPayload owns the payload formats used by native and wrapper events.
//

import Foundation

// MARK: - Screen Name Tracking Protocol

/// Retains the current screen and supplies its native or wrapper event context.
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
    func buildScreenDictionaryForEvent() -> [String: String]

    /// Builds the minimal screen context used by wrapper interaction events.
    func buildScreenDictionaryForWrapperEvent() -> [String: String]

    /// Resets all tracked state to initial values
    func reset()
}

// MARK: - Screen Name Tracker

/// Publishes immutable screen snapshots between capture callers and analytics queues.
internal final class ScreenNameTracker: ScreenNameTracking {
    // MARK: - Properties

    /// Associated object key for storing untracked screen flags
    internal static var untrackedScreenKey: UInt8 = 0

    /// UIKit and wrapper callers write screen context while analytics reads snapshots on other queues.
    private let currentPayload = AtomicReference<ScreenTrackingPayload?>(nil)

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
        currentPayload.value = payload
    }

    /// Returns the current screen tracking payload
    /// - Returns: The current screen payload or nil
    func getCurrentPayload() -> ScreenTrackingPayload? {
        return currentPayload.value
    }

    /// Builds a screen context dictionary from the current payload for event properties
    func buildScreenDictionary() -> [String: Any] {
        currentPayload.value?.toDictionary() ?? [:]
    }

    /// Builds a screen context dictionary from the current payload for event properties
    func buildScreenDictionaryForEvent() -> [String: String] {
        currentPayload.value?.toEventDictionary() ?? [:]
    }

    /// Builds every field from one retained snapshot, including callers that attach hierarchy metadata.
    static func buildScreenDictionaryForEvent(from payload: ScreenTrackingPayload?) -> [String: String] {
        payload?.toEventDictionary() ?? [:]
    }

    /// Wrapper events use their supplied hierarchy and only need the current screen title here.
    func buildScreenDictionaryForWrapperEvent() -> [String: String] {
        currentPayload.value?.toWrapperEventDictionary() ?? [:]
    }

    /// Resets all tracked state to initial values
    func reset() {
        currentPayload.value = nil
    }
}
