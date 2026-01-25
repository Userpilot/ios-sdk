//
//  UIKitScreenTracker.swift
//  Userpilot
//
//  Created by Motasem Hamed on 05/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIKitScreenTracker manages automatic screen tracking for UIKit applications,
//  handling screen transitions and click analytics through notification observers.
//

import Foundation
import UIKit

/// `UIKitScreenTracker` manages automatic screen and click tracking for UIKit applications.
internal class UIKitAutoCaptureEngine {
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

    /// Creates a UIKit screen tracker and sets up auto capture if enabled
    /// - Parameter container: Dependency injection container
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.config = container.resolve(Userpilot.Config.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)

        let screenTrackingEnabled = config.uiKitAutoCaptureScreensEnabled
        let clickTrackingEnabled = config.uiKitAutoCaptureClicksEnabled

        if screenTrackingEnabled || clickTrackingEnabled {
            setupAutoCaptureScreens()
            if screenTrackingEnabled {
                config.logger.info("Automatic UIKit screen tracking enabled")
            }
        }
        if clickTrackingEnabled {
            setupAutoCaptureClickes()
            config.logger.info("Automatic UIKit click tracking enabled")
        }
    }

    // MARK: - Private Methods

    /// Sets up automatic screen tracking by swizzling and adding notification observers
    private func setupAutoCaptureScreens() {
        UIViewController.updateAutoCaptureScreens(uiKitEnabled: true)
        AutoCaptureSwizzler.swizzleUIKitScreenTracking()
        AutoCaptureSwizzler.swizzleTabBarTracking()

        NotificationCenter.userpilot.addObserver(
            self,
            selector: #selector(screenTracked),
            name: .userpilotTrackedScreen,
            object: nil)
        NotificationCenter.userpilot.addObserver(
            self,
            selector: #selector(screenTabTracked),
            name: .userpilotTrackedTab,
            object: nil)
    }

    /// Sets up automatic click tracking by swizzling and adding notification observers
    private func setupAutoCaptureClickes() {
        UIWindow.updateAutoCaptureClicks(uiKitEnabled: true)
        AutoCaptureSwizzler.swizzleClickTracking()
        NotificationCenter.userpilot.addObserver(
            self,
            selector: #selector(clickTracked),
            name: .userpilotTrackedClick,
            object: nil)
    }

    /// Handles screen tracking notifications and publishes analytics events
    /// - Parameter notification: The notification containing screen name
    @objc
    private func screenTracked(notification: Notification) {
        let title: String? = notification.value()
        guard let title = title, lastTrackedScreen != title else { return }

        screenNameTracker.updateScreen(title)
        lastTrackedScreen = title
        if config.uiKitAutoCaptureScreensEnabled {
            analyticsPublisher.publish(Event(type: .screen(title)), isInternalEvent: false)
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

        if let source = properties["auto_capture_source"] as? String, source != "uikit" {
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

        enrichedProperties["event_uid"] = UIKitViewResolver.generateEventUID(
            screenName: currentScreen,
            properties: enrichedProperties
        )

        analyticsPublisher.publish(
            Event(type: .event("AutoCapture-Click"), properties: enrichedProperties),
            isInternalEvent: false)
    }
}
