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

// MARK: - Tab Tracking Payload

/// Payload containing tab tracking information (used by SwiftUI engine)
internal struct TabTrackingPayload {
    /// The tab name or title
    let name: String

    /// The tab index
    let index: Int
}

// MARK: - Screen Tracking Payload

/// Payload containing comprehensive screen tracking information for auto capture events.
internal struct ScreenTrackingPayload {
    // MARK: - Properties

    /// The source of the auto capture (e.g., "UIKit", "SwiftUI")
    let autoCaptureSource: String

    /// The current screen name
    let currentScreen: String

    /// The class name of the current screen's view controller
    let screenClass: String

    /// The type of screen (e.g., "ViewController", "NavigationController")
    let screenType: String

    /// The previous screen name
    let previousScreen: String

    /// The class name of the previous screen's view controller
    let previousScreenClass: String

    /// The navigation path to the current screen
    let screenPath: String

    /// The navigation title of the screen
    let navigationTitle: String?

    /// Whether this is a root screen
    let isRootScreen: Bool

    /// The timestamp of the event
    let timestamp: TimeInterval

    /// Whether this view controller is a Userpilot container class
    let isUserpilotContainerClass: Bool

    /// The name of the selected tab (if in a tab bar controller)
    let tabName: String?

    /// The index of the selected tab (if in a tab bar controller)
    let tabIndex: Int?

    /// The accessibilityIdentifier of the view controller
    let vcAccessibilityIdentifier: String?

    /// The accessibilityLabel of the view controller
    let vcAccessibilityLabel: String?

    // MARK: - Enrichment

    /// Creates an enriched copy with previous screen information
    /// - Parameters:
    ///   - previousScreen: The previous screen name
    ///   - previousScreenClass: The previous screen class name
    /// - Returns: A new payload with the previous screen info filled in
    func withPreviousScreen(_ previousScreen: String, previousScreenClass: String) -> ScreenTrackingPayload {
        ScreenTrackingPayload(
            autoCaptureSource: autoCaptureSource,
            currentScreen: currentScreen,
            screenClass: screenClass,
            screenType: screenType,
            previousScreen: previousScreen,
            previousScreenClass: previousScreenClass,
            screenPath: screenPath,
            navigationTitle: navigationTitle,
            isRootScreen: isRootScreen,
            timestamp: timestamp,
            isUserpilotContainerClass: isUserpilotContainerClass,
            tabName: tabName,
            tabIndex: tabIndex,
            vcAccessibilityIdentifier: vcAccessibilityIdentifier,
            vcAccessibilityLabel: vcAccessibilityLabel
        )
    }

    // MARK: - Conversion

    /// Converts the payload to a dictionary for event properties
    /// - Returns: Dictionary representation of the payload
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "auto_capture_source": autoCaptureSource,
            "current_screen": currentScreen,
            "screen_class": screenClass,
            "screen_type": screenType,
            "previous_screen": previousScreen,
            "previous_screen_class": previousScreenClass,
            "screen_path": screenPath,
            "is_root_screen": isRootScreen,
            "timestamp": timestamp,
            "is_userpilot_container_class": isUserpilotContainerClass
        ]

        if let navigationTitle = navigationTitle {
            dict["navigation_title"] = navigationTitle
        }

        if let tabName = tabName {
            dict["tab_name"] = tabName
        }

        if let tabIndex = tabIndex {
            dict["tab_index"] = tabIndex
        }

        if let vcAccessibilityIdentifier = vcAccessibilityIdentifier {
            dict["vc_accessibility_identifier"] = vcAccessibilityIdentifier
        }

        if let vcAccessibilityLabel = vcAccessibilityLabel {
            dict["vc_accessibility_label"] = vcAccessibilityLabel
        }

        return dict
    }
}

// MARK: - Screen Name Tracking Protocol

/// `ScreenNameTracking` defines the interface for tracking screen navigation and tab states.
internal protocol ScreenNameTracking: AnyObject {
    /// Updates the current screen with full payload
    /// - Parameter payload: The screen tracking payload
    func updateScreen(with payload: ScreenTrackingPayload)

    /// Updates the current screen and moves current screen to previous (legacy support)
    /// - Parameter screen: The new screen name
    func updateScreen(_ screen: String)

    /// Returns the current screen name
    /// - Returns: Current screen name string
    func getCurrentScreen() -> String

    /// Returns the previous screen name
    /// - Returns: Previous screen name string
    func getPreviousScreen() -> String

    /// Returns the current screen class name
    /// - Returns: Current screen class string
    func getCurrentScreenClass() -> String

    /// Returns the previous screen class name
    /// - Returns: Previous screen class string
    func getPreviousScreenClass() -> String

    /// Returns the current screen tracking payload
    /// - Returns: The current screen payload or nil
    func getCurrentPayload() -> ScreenTrackingPayload?

    /// Builds a screen context dictionary for event properties
    /// - Returns: Dictionary with current_screen, screen_class, screen_type, previous_screen, etc.
    func buildScreenDictionary() -> [String: Any]

    /// Sets the currently selected tab name
    /// - Parameter tabName: The tab name
    func setSelectedTab(_ tabName: String)

    /// Sets the currently selected tab index
    /// - Parameter tabIndex: The tab index
    func setSelectedTabIndex(_ tabIndex: Int)

    /// Returns current tab information if available
    /// - Returns: Tuple with tab name and index, or nil
    func getTabInfo() -> (name: String, index: Int)?

    /// Resets all tracked state to initial values
    func reset()
}

// MARK: - Screen Name Tracker

/// `ScreenNameTracker` implements screen and tab state tracking for analytics.
internal final class ScreenNameTracker: ScreenNameTracking {
    // MARK: - Properties

    /// Associated object key for storing untracked screen flags
    internal static var untrackedScreenKey: UInt8 = 0

    /// The current screen name
    private var currentScreen: String = ""

    /// The previous screen name
    private var previousScreen: String = ""

    /// The current screen class name
    private var currentScreenClass: String = ""

    /// The previous screen class name
    private var previousScreenClass: String = ""

    /// The current screen tracking payload
    private var currentPayload: ScreenTrackingPayload?

    /// The currently selected tab name
    private var selectedTab: String?

    /// The currently selected tab index
    private var selectedTabIndex: Int?

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
        previousScreen = currentScreen
        previousScreenClass = currentScreenClass
        currentScreen = payload.currentScreen
        currentScreenClass = payload.screenClass
        currentPayload = payload
    }

    /// Updates the current screen and moves the current screen to previous
    /// - Parameter screen: The new screen name
    func updateScreen(_ screen: String) {
        previousScreen = currentScreen
        currentScreen = screen
    }

    /// Returns the current screen name
    /// - Returns: Current screen name string
    func getCurrentScreen() -> String {
        return currentScreen
    }

    /// Returns the previous screen name
    /// - Returns: Previous screen name string
    func getPreviousScreen() -> String {
        return previousScreen
    }

    /// Returns the current screen class name
    /// - Returns: Current screen class string
    func getCurrentScreenClass() -> String {
        return currentScreenClass
    }

    /// Returns the previous screen class name
    /// - Returns: Previous screen class string
    func getPreviousScreenClass() -> String {
        return previousScreenClass
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
            "current_screen": payload.currentScreen,
            "screen_class": payload.screenClass,
            "screen_type": payload.screenType,
            "previous_screen": payload.previousScreen,
            "previous_screen_class": payload.previousScreenClass,
            "screen_path": payload.screenPath,
            "is_root_screen": payload.isRootScreen
        ]

        if let navTitle = payload.navigationTitle {
            screen["navigation_title"] = navTitle
        }
        if let tabName = payload.tabName {
            screen["tab_name"] = tabName
        }
        if let tabIndex = payload.tabIndex {
            screen["tab_index"] = tabIndex
        }
        if let vcAccessibilityIdentifier = payload.vcAccessibilityIdentifier {
            screen["vc_accessibility_identifier"] = vcAccessibilityIdentifier
        }
        if let vcAccessibilityLabel = payload.vcAccessibilityLabel {
            screen["vc_accessibility_label"] = vcAccessibilityLabel
        }

        return screen
    }

    /// Sets the currently selected tab name
    /// - Parameter tabName: The tab name
    func setSelectedTab(_ tabName: String) {
        selectedTab = tabName
    }

    /// Sets the currently selected tab index
    /// - Parameter tabIndex: The tab index
    func setSelectedTabIndex(_ tabIndex: Int) {
        selectedTabIndex = tabIndex
    }

    /// Returns current tab information if available
    /// - Returns: Tuple with tab name and index, or nil
    func getTabInfo() -> (name: String, index: Int)? {
        guard let tabName = selectedTab, let tabIndex = selectedTabIndex else {
            return nil
        }
        return (tabName, tabIndex)
    }

    /// Resets all tracked state to initial values
    func reset() {
        currentScreen = ""
        previousScreen = ""
        currentScreenClass = ""
        previousScreenClass = ""
        currentPayload = nil
        selectedTab = nil
        selectedTabIndex = nil
    }
}
