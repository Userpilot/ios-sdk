//
//  UIKitAutoCaptureEngine.swift
//  Userpilot
//
//  Created by Motasem Hamed on 05/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIKitAutoCaptureEngine manages automatic screen and interaction tracking for UIKit applications,
//  handling screen transitions, control interactions, table/collection view selections, and text input.
//

import Foundation
import UIKit

/// `UIKitAutoCaptureEngine` manages automatic screen and interaction tracking for UIKit applications.
internal class AutoCaptureEngine {
    // MARK: - Properties

    /// The last screen name that was tracked to avoid duplicate events
    private var lastTrackedScreen: String?

    /// Analytics publisher for sending tracking events
    private let analyticsPublisher: AnalyticsPublishing

    /// SDK configuration containing tracking settings
    private let config: Userpilot.Config

    /// Screen name tracker for managing navigation state
    private let screenNameTracker: ScreenNameTracking

    /// Screen time tracker for foreground-only time per screen
    private let screenTimeTracker: ScreenTimeTracking

    // MARK: - Initialization

    /// Creates a UIKit auto capture engine and sets up tracking if enabled
    /// - Parameter container: Dependency injection container
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.config = container.resolve(Userpilot.Config.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)
        self.screenTimeTracker = container.resolve(ScreenTimeTracking.self)

        let screenTrackingEnabled = config.enableScreenAutocapture
        let interactionTrackingEnabled = config.enableInteractionAutocapture

        if screenTrackingEnabled || interactionTrackingEnabled {
            setupAutoCaptureScreens()
            if screenTrackingEnabled {
                config.logger.info("Automatic UIKit screen tracking enabled")
            }
        }

        if interactionTrackingEnabled {
            setupAutoCaptureInteractions()
            config.logger.info("Automatic UIKit interaction tracking enabled")
        }
    }

    // MARK: - Setup Methods

    /// Sets up automatic screen tracking by swizzling
    private func setupAutoCaptureScreens() {
        AutoCaptureSwizzler.swizzleUIKitScreenTracking()
        AutoCaptureSwizzler.swizzleTabBarTracking()
    }

    /// Sets up automatic interaction tracking by swizzling and notifications
    private func setupAutoCaptureInteractions() {
        // Touch/click tracking via UIWindow.sendEvent
        // This also captures table view cell and collection view cell taps
        AutoCaptureSwizzler.swizzleClickTracking()

        // All target–action interactions via UIApplication.sendAction (UIControl, UIBarButtonItem, UIMenu, etc.)
        AutoCaptureSwizzler.swizzleApplicationSendAction()

        // UIPickerView row selections via delegate hooking
        AutoCaptureSwizzler.swizzlePickerViewDelegate()

        // Text input tracking via notifications
        AutoCaptureSwizzler.registerTextFieldNotifications()
        AutoCaptureSwizzler.registerTextViewNotifications()
    }

    // MARK: - Screen Tracking Methods

    /// Handles screen tracking and publishes analytics events as track events
    /// - Parameter payload: The screen tracking payload from the view controller
    internal func handleScreenTracked(_ payload: ScreenTrackingPayload) {
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        let acceptedSources = [FrameworkType.uiKit.rawValue, FrameworkType.swiftUI.rawValue]
        guard acceptedSources.contains(payload.autoCaptureSource) else { return }

        // Avoid duplicate events
        guard lastTrackedScreen != payload.currentScreen else { return }

        let previousDurationMs = screenTimeTracker.onScreenChanged(payload)

        // Flush any cached events from the previous screen (text input, slider, etc.)
        InteractionEventCache.flushAll()

        lastTrackedScreen = payload.currentScreen

        // Enrich payload with previous screen info from tracker
        let enrichedPayload = payload.withPreviousScreen(
            screenNameTracker.getCurrentScreen(),
            previousScreenClass: screenNameTracker.getCurrentScreenClass()
        )

        screenNameTracker.updateScreen(with: enrichedPayload)

        var properties = enrichedPayload.toDictionary()
        if let previousDurationMs = previousDurationMs {
            properties[Constants.AutoCapture.previousScreenDurationMsKey] = previousDurationMs
        }
        let event = Event(
            type: .event("screen-auto-capture"),
            properties: properties
        )
        debugPrint("---------------")
        debugPrint(event)
        // analyticsPublisher.publish(event, isInternalEvent: false)
    }

    /// Handles tab selection tracking
    /// - Parameters:
    ///   - tabName: The name of the selected tab
    ///   - tabIndex: The index of the selected tab
    internal func handleTabSelected(name tabName: String, index tabIndex: Int) {
        screenNameTracker.setSelectedTab(tabName)
        screenNameTracker.setSelectedTabIndex(tabIndex)
    }

    // MARK: - Interaction Tracking Methods

    /// Handles interaction events from UIControl, UITableView, UICollectionView, and text inputs
    /// - Parameter payload: The interaction payload containing event details
    internal func handleInteraction(_ payload: InteractionPayload) {
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        guard config.enableInteractionAutocapture else { return }
        guard payload.autoCaptureSource == FrameworkType.uiKit.rawValue else { return }

        var properties = payload.toDictionary()
        properties["screen"] = screenNameTracker.buildScreenDictionary()

        // let eventName = eventNameForInteractionType(payload.interactionType)
        let eventName = payload.interactionType.rawValue

        debugPrint("---------------")
        debugPrint(properties)
        print("AAAA \(properties)")
//        analyticsPublisher.publish(
//            Event(type: .event(eventName), properties: properties),
//            isInternalEvent: false
//        )
    }

    /// Handles click tracking from UIWindow.sendEvent (regular view taps)
    /// - Parameter properties: The click event properties
    internal func handleClickTracked(_ properties: [String: Any]) {
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        guard config.enableInteractionAutocapture else { return }

        let acceptedSources = [FrameworkType.uiKit.rawValue, FrameworkType.swiftUI.rawValue]
        if let source = properties["auto_capture_source"] as? String, !acceptedSources.contains(source) {
            return
        }

        var enrichedProperties = properties
        enrichedProperties["screen"] = screenNameTracker.buildScreenDictionary()

        debugPrint("---------------")
        debugPrint(enrichedProperties)
        print("AAAA \(enrichedProperties)")
//        analyticsPublisher.publish(
//            Event(type: .event("interaction"), properties: enrichedProperties),
//            isInternalEvent: false
//        )
    }
}

enum FrameworkType: String {
    case uiKit   = "UIKit"
    case swiftUI = "SwiftUI"
}
