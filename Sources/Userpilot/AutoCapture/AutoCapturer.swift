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

/**
 The `AutoCapturing` protocol defines the entry points used by swizzled UIKit hooks and
 extensions to forward automatic screen and interaction capture into analytics.

 Concrete implementations enrich payloads and publish via `AnalyticsPublishing`.
 */
internal protocol AutoCapturing: AnyObject {

    /// Records a screen transition and publishes a `.screen` analytics event when allowed.
    func trackScreen(_ payload: ScreenTrackingPayload)

    /// Publishes a `mobile_autocapture` event for tab-bar selection.
    func handleTabSelected(name tabName: String, index tabIndex: Int)

    /// Publishes a structured interaction (control, cell, text input, etc.) as `mobile_autocapture`.
    func handleInteractionEvent(_ payload: InteractionPayload)

    /// Publishes window-level tap properties as `mobile_autocapture` when they pass noise filtering.
    func handleClickTracked(_ properties: [String: Any])
}

// Responsible for automatically capturing screen transitions and user interaction events
// in UIKit-based apps. Works via method swizzling and notification observation.
// All captured events are enriched with screen context and app metadata before publishing.

internal class AutoCapturer {

    // MARK: - Dependencies

    /// Publishes enriched analytics events to the configured backend.
    private let analyticsPublisher: AnalyticsPublishing

    /// SDK configuration: holds feature flags, framework info, and the logger.
    private let config: Userpilot.Config

    /// Tracks the current screen name/class and navigation history.
    private let screenNameTracker: ScreenNameTracking

    /// Tracks foreground-only time spent on each screen.
    private let screenTimeTracker: ScreenTimeTracking

    // MARK: - Computed Helpers

    /// Reusable internal properties shared across all events.
    /// Provides UIFramework tagging for every event without repetition.
    private var baseInternalProperties: [String: Any] {
        [AutoCaptureConstants.uiFramework: config.appFramework.rawValue]
    }

    /// Returns the current screen dictionary, or nil if screen context is unavailable.
    /// Centralises the nil-check so call sites stay clean.
    private var currentScreenDictionary: [String: Any]? {
        guard screenNameTracker.getCurrentPayload() != nil else { return nil }
        return screenNameTracker.buildScreenDictionaryForEvent()
    }

    // MARK: - Initialization

    /// Initialises the engine and conditionally enables screen and/or interaction autocapture.
    ///
    /// Screen tracking uses swizzled `viewDidAppear` / tab-bar callbacks.
    /// Interaction tracking uses swizzled `UIWindow.sendEvent`, `UIApplication.sendAction`,
    /// picker-view delegate hooks, and text-field/text-view notifications.
    ///
    /// - Parameter container: DI container that supplies all required dependencies.
    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)
        self.screenTimeTracker = container.resolve(ScreenTimeTracking.self)

        // Screen swizzles are required for both features (interaction tracking
        // needs to know which screen an event occurred on).
        if config.enableScreenAutoCapture {
            setupAutoCaptureScreens()
            config.logger.info("📊 Automatic UIKit screen tracking enabled")
        }

        if config.enableInteractionAutoCapture {
            setupAutoCaptureInteractions()
            config.logger.info("📊 Automatic UIKit interaction tracking enabled")
        }
    }

    // MARK: - Private Setup

    /// Swizzles view-controller lifecycle and tab-bar selection hooks
    /// so screen transitions are captured without manual instrumentation.
    private func setupAutoCaptureScreens() {
        AutoCaptureSwizzler.swizzleUIKitScreenTracking()
        AutoCaptureSwizzler.swizzleTabBarTracking()
    }

    /// Registers all interaction hooks:
    /// - `UIWindow.sendEvent`          → tap / touch tracking
    /// - `UIApplication.sendAction`    → UIControl, UIBarButtonItem, UIMenu
    /// - Picker-view delegate swizzle  → UIPickerView row selections
    /// - Text notifications            → UITextField / UITextView edits
    private func setupAutoCaptureInteractions() {
        AutoCaptureSwizzler.swizzleClickTracking()
        AutoCaptureSwizzler.swizzleApplicationSendAction()
        AutoCaptureSwizzler.swizzlePickerViewDelegate()
        AutoCaptureSwizzler.registerTextFieldNotifications()
        AutoCaptureSwizzler.registerTextViewNotifications()
    }
}

// MARK: - AutoCapturing

extension AutoCapturer: AutoCapturing {

    // MARK: - Screen Tracking

    func trackScreen(_ payload: ScreenTrackingPayload) {
        tryCatch {
            guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }

            if payload.isDialogPresentation {
                publishDialogPresentedAutocapture(from: payload)
                return
            }

            screenNameTracker.updateScreen(with: payload)

            // Bail out if the tracker hasn't resolved a valid screen class yet.
            guard let screenClass = screenNameTracker.getCurrentPayload()?.screenClass else { return }

            let properties = buildScreenEventProperties()
            let event = makeEvent(type: EventType.screen(screenClass), properties: properties)

            analyticsPublisher.publish(event)
        }
    }

    // MARK: - Tab Tracking

    func handleTabSelected(name tabName: String, index tabIndex: Int) {
        guard isInteractionTrackingActive else { return }

        let interactionType = InteractionType.tabSelected
        var properties = buildTabProperties(name: tabName, index: tabIndex)
        let internalProps = buildInternalProperties(for: interactionType)
        properties.merge(internalProps) { (_, new) in new }

        let event = makeEvent(
            type: EventType.autoCaptureEvent,
            properties: properties,
            interactionEventName: interactionType.toInteractionEventType().rawValue
        )

        analyticsPublisher.publish(event)
    }

    // MARK: - Interaction Tracking

    func handleInteractionEvent(_ payload: InteractionPayload) {
        publishInteractionPayload(payload)
    }

    func handleClickTracked(_ properties: [String: Any]) {
        guard isInteractionTrackingActive else { return }
        guard shouldPublishWindowLevelTouch(properties) else { return }
        guard let payload = interactionPayload(fromWindowClick: properties) else { return }
        publishInteractionPayload(payload)
    }
}

// MARK: - Private Helpers

private extension AutoCapturer {

    // MARK: Guard Helpers

    /// `true` when interaction tracking is both globally enabled and not paused at runtime.
    var isInteractionTrackingActive: Bool {
        !AutocaptureViewConfiguration.isAutoCaptureStopped && config.enableInteractionAutoCapture
    }

    // MARK: Window-level touch filtering

    /// `UIScrollView` / `UITableView` / `UICollectionView` / `UIStackView`, bare `UIView`, and generic SwiftUI host.
    private static let structuralWindowTouchElementTypes: Set<String> = [
        String(describing: UIScrollView.self),
        String(describing: UITableView.self),
        String(describing: UICollectionView.self),
        String(describing: UIStackView.self),
        String(describing: UIView.self),
        AutoCaptureConstants.swiftUIView
    ]

    /// True when any identifying string is present (including redacted placeholder).
    private func windowTouchHasMetadata(_ properties: [String: Any]) -> Bool {
        let keys: [String] = [
            AutoCaptureConstants.elementText,
            AutoCaptureConstants.accessibilityLabel,
            AutoCaptureConstants.accessibilityIdentifier,
            AutoCaptureConstants.elementLabel,
            AutoCaptureConstants.accessibilityId
        ]
        for key in keys {
            guard let string = properties[key] as? String else { continue }
            if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }

    /// Drops taps on structural containers and bare SwiftUI views when there is no text or accessibility signal.
    private func shouldPublishWindowLevelTouch(_ properties: [String: Any]) -> Bool {
        guard let elementType = properties[AutoCaptureConstants.elementType] as? String else {
            return false
        }
        if windowTouchHasMetadata(properties) {
            return true
        }
        if Self.structuralWindowTouchElementTypes.contains(elementType) {
            return false
        }
        return true
    }

    /// Maps window `sendEvent` dictionaries into the same payload shape as other interaction paths.
    private func interactionPayload(fromWindowClick properties: [String: Any]) -> InteractionPayload? {
        guard let elementType = properties[AutoCaptureConstants.elementType] as? String else {
            return nil
        }
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: elementType
        )
        if let text = properties[AutoCaptureConstants.elementText] as? String {
            payload.elementText = text
        } else if let label = properties[AutoCaptureConstants.elementLabel] as? String {
            payload.elementText = label
        }
        if let a11yLabel = properties[AutoCaptureConstants.accessibilityLabel] as? String {
            payload.accessibilityLabel = a11yLabel
        }
        if let a11yId = properties[AutoCaptureConstants.accessibilityIdentifier] as? String {
            payload.accessibilityIdentifier = a11yId
        } else if let swiftUIId = properties[AutoCaptureConstants.accessibilityId] as? String {
            payload.accessibilityIdentifier = swiftUIId
        }
        payload.elementPath = properties[AutoCaptureConstants.hierarchy] as? String
        payload.isLongPress = properties[AutoCaptureConstants.isLongPress] as? Bool
        return payload
    }

    /// Publishes an interaction using the same merge rules as `handleInteractionEvent`.
    private func publishInteractionPayload(_ payload: InteractionPayload) {
        guard isInteractionTrackingActive else { return }
        publishAutoCaptureInteractionPayload(payload)
    }

    /// When hierarchy was built with no owning VC, the root is
    /// `unknownScreenHierarchyPlaceholder`; swap in the tracked screen class.
    private func replaceUnknownScreenPlaceholderInHierarchy(_ properties: inout [String: Any]) {
        let placeholder = AutoCaptureConstants.unknownScreenHierarchyPlaceholder
        guard var hierarchy = properties[AutoCaptureConstants.hierarchy] as? String,
              hierarchy.contains(placeholder) else { return }
        guard let screenClass = screenNameTracker.getCurrentPayload()?.screenClass,
              !screenClass.isEmpty else { return }
        hierarchy = hierarchy.replacingOccurrences(of: placeholder, with: screenClass)
        properties[AutoCaptureConstants.hierarchy] = hierarchy
    }

    /// Shared `mobile_autocapture` merge and publish. `publishInteractionPayload`
    /// applies the interaction guard first; dialog events call this directly.
    private func publishAutoCaptureInteractionPayload(_ payload: InteractionPayload) {
        var properties: [String: Any] = [:]
        properties.merge(payload.toDictionary()) { _, new in new }
        var internalProps = buildInternalProperties(for: payload.interactionType)
        internalProps.merge(payload.toSourceDictionary()) { _, new in new }
        properties.merge(internalProps) { _, new in new }
        replaceUnknownScreenPlaceholderInHierarchy(&properties)

        let event = makeEvent(
            type: EventType.autoCaptureEvent,
            properties: properties,
            interactionEventName: payload.interactionType.toInteractionEventType().rawValue
        )
        analyticsPublisher.publish(event)
    }

    /// `UIAlertController` is not emitted as a screen view; send
    /// `dialog_presented` with title/message when screen autocapture runs.
    private func publishDialogPresentedAutocapture(from screenPayload: ScreenTrackingPayload) {
        var payload = InteractionPayload(
            interactionType: .viewPresented,
            elementType: AutoCaptureConstants.elementTypeUIAlertController
        )
        payload.dialogTitle = screenPayload.alertTitle
        payload.dialogMessage = screenPayload.alertMessage
        publishAutoCaptureInteractionPayload(payload)
    }

    // MARK: Dictionary Builders

    /// Builds the properties dictionary for a screen event.
    func buildScreenEventProperties() -> [String: Any] {
        var properties: [String: Any] = [:]

        // flatten screen properties
        properties.merge(screenNameTracker.buildScreenDictionary()) { _, new in new }

        // flatten internal properties
        properties[AutoCaptureConstants.appSource] = config.appFramework.rawValue

        return properties
    }

    /// Builds the properties dictionary for a tab-selection event.
    func buildTabProperties(name: String, index: Int) -> [String: Any] {
        var props: [String: Any] = [
            AutoCaptureConstants.tabName: name,
            AutoCaptureConstants.tabIndex: index
        ]
        return props
    }

    /// Builds the `internalProperties` dictionary for an interaction event.
    /// Always includes the raw interaction type and the UI framework tag.
    func buildInternalProperties(for interactionType: InteractionType) -> [String: Any] {
        var props = baseInternalProperties
        props[AutoCaptureConstants.rawInteractionType] = interactionType.rawValue
        return props
    }

    // MARK: Event Factory

    /// Creates a fully-formed `Event` with shared decorator properties and SDK version.
    ///
    /// - Parameters:
    ///   - type:                 The event type (`.screen` or `.event`).
    ///   - properties:           Domain-specific event properties.
    ///   - interactionEventName: Optional interaction event name for autocapture events.
    /// - Returns: A ready-to-publish `Event`.
    func makeEvent(
        type: EventType,
        properties: [String: Any],
        interactionEventName: String? = nil
    ) -> Event {
        Event(
            type: type,
            properties: properties,
            screen: currentScreenDictionary,
            interactionEventName: interactionEventName
        )
    }

}
