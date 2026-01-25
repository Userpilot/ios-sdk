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

/// `ScreenNameTracking` defines the interface for tracking screen navigation and tab states.
/// `ScreenNameTracking` defines the interface for tracking screen navigation and tab states.
internal protocol ScreenNameTracking: AnyObject {
    /// Updates the current screen and moves current screen to previous
    /// - Parameter screen: The new screen name
    func updateScreen(_ screen: String)

    /// Returns the current screen name
    /// - Returns: Current screen name string
    func getCurrentScreen() -> String

    /// Returns the previous screen name
    /// - Returns: Previous screen name string
    func getPreviousScreen() -> String

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

/// `ScreenNameTracker` implements screen and tab state tracking for analytics.
internal final class ScreenNameTracker: ScreenNameTracking {
    // MARK: - Properties

    /// Associated object key for storing untracked screen flags
    public static var untrackedScreenKey: UInt8 = 0

    /// The current screen name
    private var currentScreen: String = ""

    /// The previous screen name
    private var previousScreen: String = ""

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
        selectedTab = nil
        selectedTabIndex = nil
    }
}
