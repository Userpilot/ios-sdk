//
//  SwiftUIScreenTracker.swift
//  Userpilot
//
//  Created by Motasem Hamed on 11/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  SwiftUIScreenTracker manages automatic screen tracking for SwiftUI applications,
//  handling screen transitions and click analytics through notification observers.
//

import SwiftUI
import UIKit

/// `SwiftUIScreenTracker` manages automatic screen and click tracking for SwiftUI applications.
internal class SwiftUIAutoCaptureEngine {
    // MARK: - Properties

    /// The last screen name that was tracked to avoid duplicate events
    private var lastTrackedScreen: String?

    /// Analytics publisher for sending tracking events
    private let analyticsPublisher: AnalyticsPublishing

    /// SDK configuration containing tracking settings
    private let config: Userpilot.Config

    /// Screen name tracker for managing navigation state
    private let screenNameTracker: ScreenNameTracking

    // MARK: - Initialization

    /// Creates a SwiftUI screen tracker and sets up auto capture if enabled
    /// - Parameter container: Dependency injection container
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.config = container.resolve(Userpilot.Config.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)

        let screenTrackingEnabled = config.enableScreenAutocapture
        let clickTrackingEnabled = config.enableInteractionAutocapture

        if screenTrackingEnabled || clickTrackingEnabled {
            setupAutoCaptureScreens()
            if screenTrackingEnabled {
                config.logger.info("Automatic SwiftUI screen tracking enabled")
            }
        }
        if clickTrackingEnabled {
            setupAutoCaptureClicks()
            config.logger.info("Automatic SwiftUI click tracking enabled")
        }
    }

    // MARK: - Private Methods

    /// Sets up automatic screen tracking by swizzling and adding notification observers
    private func setupAutoCaptureScreens() {
//        UIViewController.updateAutoCaptureScreens(swiftUIEnabled: true)
//        AutoCaptureSwizzler.swizzleSwiftUIScreenTracking()
//        AutoCaptureSwizzler.swizzleTabBarTracking()
//
//        // Listen for screen tracking notifications
//        NotificationCenter.userpilot.addObserver(
//            self,
//            selector: #selector(screenTracked),
//            name: .userpilotTrackedScreen,
//            object: nil
//        )
//        NotificationCenter.userpilot.addObserver(
//            self,
//            selector: #selector(screenTabTracked),
//            name: .userpilotTrackedTab,
//            object: nil
//        )
    }

    /// Sets up automatic click tracking by swizzling and adding notification observers
    private func setupAutoCaptureClicks() {
//        UIWindow.updateAutoCaptureClicks(swiftUIEnabled: true)
//        AutoCaptureSwizzler.swizzleClickTracking()
//        NotificationCenter.userpilot.addObserver(
//            self,
//            selector: #selector(clickTracked),
//            name: .userpilotTrackedClick,
//            object: nil
//        )
    }

    /// Handles screen tracking notifications and publishes analytics events
    /// - Parameter notification: The notification containing screen name
    @objc
    private func screenTracked(notification: Notification) {
        let screenName: String? = notification.value()
        guard let screenName = screenName, lastTrackedScreen != screenName else { return }

        screenNameTracker.updateScreen(screenName)
        lastTrackedScreen = screenName
        if config.enableScreenAutocapture {
            analyticsPublisher.publish(Event(type: .screen(screenName)), isInternalEvent: false)
        }
    }

    /// Handles tab selection tracking notifications
    /// - Parameter notification: The notification containing tab information
    @objc
    private func screenTabTracked(notification: Notification) {
        guard let payload: TabTrackingPayload = notification.value() else { return }
        screenNameTracker.setSelectedTab(payload.name)
        screenNameTracker.setSelectedTabIndex(payload.index)
    }

    /// Handles click tracking notifications and publishes enriched analytics events
    /// - Parameter notification: The notification containing click properties
    @objc
    private func clickTracked(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let properties = userInfo as? [String: Any]
        else {
            return
        }

        if let source = properties["auto_capture_source"] as? String, source != "swiftui" {
            return
        }

        var enrichedProperties = properties
        let currentScreen = screenNameTracker.getCurrentScreen()
        let previousScreen = screenNameTracker.getPreviousScreen()

        enrichedProperties["current_screen"] = currentScreen
        enrichedProperties["previous_screen"] = previousScreen

        if let tabInfo = screenNameTracker.getTabInfo() {
            enrichedProperties["tab_name"] = tabInfo.name
            enrichedProperties["tab_index"] = tabInfo.index
        }

        analyticsPublisher.publish(
            Event(type: .event("AutoCapture-Click"), properties: enrichedProperties),
            isInternalEvent: false)
    }
}
