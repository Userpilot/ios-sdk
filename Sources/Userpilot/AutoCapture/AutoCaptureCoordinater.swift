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

// swiftlint:disable file_length

import Foundation
import UIKit

/**
 The `AutoCapturing` protocol defines the entry points used by swizzled UIKit hooks and
 extensions to forward automatic screen and interaction capture into analytics.

 Concrete implementations enrich payloads and publish via `AnalyticsPublishing`.
 */
internal protocol AutoCaptureCoordinating: AnyObject {

    /// Records a screen transition and publishes a `.screen` analytics event when allowed.
    func trackScreen(_ payload: ScreenTrackingPayload)

    /// Temporarily suppresses automatic screen events caused by SDK-owned UI dismissal.
    func suppressScreenAutoCaptureAfterSDKContent()

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

internal class AutoCaptureCoordinater {

    // MARK: - Dependencies

    /// Publishes enriched analytics events to the configured backend.
    private let analyticsPublisher: AnalyticsPublishing

    /// SDK configuration: holds feature flags, framework info, and the logger.
    private let config: Userpilot.Config

    /// Tracks the current screen name/class and navigation history.
    private let screenNameTracker: ScreenNameTracking

    /// Protects pending SwiftUI screen state and SDK-content dismissal suppression.
    private let screenCaptureStateLock = NSLock()

    /// Pending SwiftUI hosting screen payload used to coalesce parent/child hosting appearances.
    private var pendingSwiftUIScreenPayload: ScreenTrackingPayload?

    /// Work item for delayed SwiftUI screen publication.
    private var pendingSwiftUIScreenWorkItem: DispatchWorkItem?

    /// Ignore automatic screen events until this date, used after SDK content fake reloads.
    private var suppressScreenCaptureUntil: Date?

    /// Small delay that lets SwiftUI emit nested hosting controller appearances before we publish.
    private let swiftUIScreenCoalescingDelay: TimeInterval = 0.08

    /// Dismissing SDK content can re-fire the underlying app's viewWillAppear chain.
    private let sdkContentDismissalSuppressionInterval: TimeInterval = 0.8

    // MARK: - Computed Helpers

    /// Reusable internal properties shared across all events.
    /// Provides UIFramework tagging for every event without repetition.

    /// Returns the current screen dictionary, or nil if screen context is unavailable.
    /// Centralises the nil-check so call sites stay clean.
    private var currentScreenDictionary: [String: Any]? {
        guard screenNameTracker.getCurrentPayload() != nil else { return nil }
        return screenNameTracker.buildScreenDictionaryForEvent(isSwiftUI: config.appFramework == .SwiftUI)
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

extension AutoCaptureCoordinater: AutoCaptureCoordinating {

    // MARK: - Screen Tracking

    /// Handles a resolved screen payload from the swizzled view-controller lifecycle.
    ///
    /// This is the main gate for automatic screen capture. It drops events while global autocapture
    /// is stopped, ignores the short SDK-content dismissal window, routes dialogs to dialog capture,
    /// and coalesces SwiftUI hosting-controller appearances before publishing a screen event.
    ///
    /// - Parameter payload: The resolved screen payload for the appearing view controller.
    func trackScreen(_ payload: ScreenTrackingPayload) {
        tryCatch {
            guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
            guard !shouldSuppressScreenAutoCapture else { return }

            if payload.isDialogPresentation {
                publishDialogPresentedAutocapture(from: payload)
                return
            }

            if shouldCoalesceSwiftUIScreen(payload) {
                coalesceSwiftUIScreen(payload)
                return
            }

            publishScreen(payload)
        }
    }

    /// Starts a short suppression window after SDK-owned content has been dismissed.
    ///
    /// Closing Userpilot content can cause the underlying app view-controller tree to receive fresh
    /// `viewWillAppear` callbacks. Those callbacks do not represent client navigation, so this method
    /// cancels any pending SwiftUI coalesced screen event and suppresses automatic screen capture
    /// briefly while UIKit/SwiftUI settles back to the already tracked screen.
    func suppressScreenAutoCaptureAfterSDKContent() {
        screenCaptureStateLock.lock()
        let workItem = pendingSwiftUIScreenWorkItem
        pendingSwiftUIScreenWorkItem?.cancel()
        pendingSwiftUIScreenWorkItem = nil
        pendingSwiftUIScreenPayload = nil
        suppressScreenCaptureUntil = Date().addingTimeInterval(sdkContentDismissalSuppressionInterval)
        screenCaptureStateLock.unlock()

        workItem?.cancel()
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

private extension AutoCaptureCoordinater {

    // MARK: Guard Helpers

    /// Whether automatic screen capture should currently be ignored.
    ///
    /// The suppression window is set by `suppressScreenAutoCaptureAfterSDKContent()` after a fake
    /// reload event. When the window expires this property clears the stored date and allows normal
    /// screen capture to resume.
    var shouldSuppressScreenAutoCapture: Bool {
        screenCaptureStateLock.lock()
        defer { screenCaptureStateLock.unlock() }

        guard let suppressScreenCaptureUntil else { return false }

        if Date() < suppressScreenCaptureUntil {
            return true
        }

        self.suppressScreenCaptureUntil = nil
        return false
    }

    /// `true` when interaction tracking is both globally enabled and not paused at runtime.
    var isInteractionTrackingActive: Bool {
        !AutocaptureViewConfiguration.isAutoCaptureStopped && config.enableInteractionAutoCapture
    }

    /// Returns `true` when a screen payload should be delayed and coalesced for SwiftUI.
    ///
    /// SwiftUI can emit multiple hosting-controller appearances for one visible screen, such as a
    /// `NavigationStackHostingController` followed immediately by a `TabHostingController`.
    /// Delaying these briefly lets the deepest/latest hosting controller win.
    ///
    /// - Parameter payload: The screen payload being considered for immediate publication.
    /// - Returns: `true` when the payload is a SwiftUI hosting-controller screen.
    func shouldCoalesceSwiftUIScreen(_ payload: ScreenTrackingPayload) -> Bool {
        config.appFramework == .SwiftUI && payload.screenClass.contains("HostingController")
    }

    /// Delays publication of a SwiftUI hosting screen so duplicate parent/child appearances collapse.
    ///
    /// Each new SwiftUI hosting payload replaces the previous pending payload and cancels the previous
    /// work item. After `swiftUIScreenCoalescingDelay`, the latest payload is published unless SDK
    /// dismissal suppression became active meanwhile.
    ///
    /// - Parameter payload: The latest SwiftUI hosting-controller screen payload.
    func coalesceSwiftUIScreen(_ payload: ScreenTrackingPayload) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.publishPendingSwiftUIScreenIfAllowed()
        }

        screenCaptureStateLock.lock()
        let previousWorkItem = pendingSwiftUIScreenWorkItem
        pendingSwiftUIScreenPayload = payload
        pendingSwiftUIScreenWorkItem = workItem
        screenCaptureStateLock.unlock()

        previousWorkItem?.cancel()
        DispatchQueue.main.asyncAfter(
            deadline: .now() + swiftUIScreenCoalescingDelay,
            execute: workItem
        )
    }

    /// Publishes the latest coalesced SwiftUI hosting payload if suppression is not active.
    ///
    /// This method runs from the delayed coalescing work item and owns the lock while it reads and
    /// clears pending state. The actual publish happens after unlocking to avoid holding state lock
    /// while analytics callbacks run.
    func publishPendingSwiftUIScreenIfAllowed() {
        screenCaptureStateLock.lock()

        if let suppressScreenCaptureUntil {
            if Date() < suppressScreenCaptureUntil {
                screenCaptureStateLock.unlock()
                return
            }
            self.suppressScreenCaptureUntil = nil
        }

        guard let payload = pendingSwiftUIScreenPayload else {
            screenCaptureStateLock.unlock()
            return
        }

        pendingSwiftUIScreenPayload = nil
        pendingSwiftUIScreenWorkItem = nil
        screenCaptureStateLock.unlock()

        publishScreen(payload)
    }

    /// Publishes a screen event immediately after updating the current screen context.
    ///
    /// This method is the shared publication path for UIKit screens and coalesced SwiftUI screens.
    /// It updates `ScreenNameTracker`, builds the backend event identity, attaches the full screen
    /// dictionary, and forwards the event to `AnalyticsPublishing`.
    ///
    /// - Parameter payload: The screen payload to persist and publish.
    func publishScreen(_ payload: ScreenTrackingPayload) {
        let previousPayload = screenNameTracker.getCurrentPayload()
        var payload = payload
        if config.appFramework == .SwiftUI {
            payload.screenNameMatchesPreviousScreen = screenNameMatchesPreviousScreen(
                payload,
                previousPayload: previousPayload
            )
        }

        screenNameTracker.updateScreen(with: payload)

        // Bail out if the tracker hasn't resolved a valid screen class yet.
        guard let screenClass = screenNameTracker.getCurrentPayload()?.screenClass else { return }

        let event = makeEvent(
            type: EventType.screen(screenEventIdentity(screenClass: screenClass, payload: payload)),
            properties: screenNameTracker.buildScreenDictionary()
        )

        analyticsPublisher.publish(event)
    }

    /// Returns whether the SwiftUI screen name/title matches the previous screen context.
    ///
    /// This is diagnostic metadata for cases where SwiftUI/NavigationStack exposes a stale UIKit
    /// title. For example, a destination without its own `.navigationTitle` may resolve to the
    /// previous screen's navigation title.
    func screenNameMatchesPreviousScreen(
        _ payload: ScreenTrackingPayload,
        previousPayload: ScreenTrackingPayload?
    ) -> Bool {
        guard config.appFramework == .SwiftUI,
              let previousPayload
        else { return false }

        let currentScreen = payload.currentScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentScreen.isEmpty else { return false }

        let previousValues = [
            previousPayload.currentScreen,
            previousPayload.navigationTitle
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return previousValues.contains(currentScreen)
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

    /// Private / internal UIKit view class names (e.g. `_UITextLayoutCanvasView`) — never publish as window taps.
    private func windowTouchIsPrivateUIKitElementType(_ elementType: String) -> Bool {
        if elementType.hasPrefix("_UI") { return true }
        if elementType.hasPrefix("_NS") { return true }
        return false
    }

    /// System keyboard chrome (`UIKBKeyView`, `TUIKBKeyView`, `UIKeyboardImpl`, …).
    private func windowTouchIsSystemKeyboardChrome(
        elementType: String,
        hierarchy: String?
    ) -> Bool {
        if elementType.hasPrefix("UIKB") { return true }
        if elementType.hasPrefix("TUIKB") { return true }
        if elementType.contains("TUIKeyplane") || elementType.contains("TUIKeyboard") { return true }
        if elementType.contains("UIKeyboardImpl") || elementType.contains("UIKeyboardLayout") {
            return true
        }
        if elementType.contains("UIKeyboardAutomatic") { return true }
        if elementType.contains("UIInputSet") || elementType.contains("_UIKB") { return true }
        if elementType.contains("UICompatibilityInputView") { return true }
        guard let hierarchy else { return false }
        if hierarchy.contains("UIKeyboardImpl") || hierarchy.contains("UIKBKeyView") { return true }
        if hierarchy.contains("TUIKB") || hierarchy.contains("UIInputSet") { return true }
        return false
    }

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

    /// Drops taps on structural containers, private `_UI…` internals, and bare SwiftUI views when there is no signal.
    private func shouldPublishWindowLevelTouch(_ properties: [String: Any]) -> Bool {
        guard let elementType = properties[AutoCaptureConstants.elementType] as? String else {
            return false
        }
        if windowTouchIsPrivateUIKitElementType(elementType) {
            return false
        }
        let hierarchy = properties[AutoCaptureConstants.hierarchy] as? String
        if windowTouchIsSystemKeyboardChrome(elementType: elementType, hierarchy: hierarchy) {
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

    /// Appends `;SCREEN_NAME` to the view hierarchy using `screenNameTracker`.
    private func appendScreenNameSegmentToHierarchy(_ properties: inout [String: Any]) {
        guard var hierarchy = properties[AutoCaptureConstants.hierarchy] as? String,
              !hierarchy.isEmpty,
              let payload = screenNameTracker.getCurrentPayload() else { return }

        let screenClass = payload.screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !screenClass.isEmpty else { return }

        let escaped = screenClass.replacingOccurrences(of: "\"", with: "\\\"")
        hierarchy += ";\(escaped)"
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
        appendScreenNameSegmentToHierarchy(&properties)

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
        guard config.enableInteractionAutoCapture else { return }
        var payload = InteractionPayload(
            interactionType: .viewPresented,
            elementType: AutoCaptureConstants.elementTypeUIAlertController
        )
        payload.dialogTitle = screenPayload.alertTitle
        payload.dialogMessage = screenPayload.alertMessage
        publishAutoCaptureInteractionPayload(payload)
    }

    // MARK: Dictionary Builders

    /// Builds the properties dictionary for a tab-selection event.
    func buildTabProperties(name: String, index: Int) -> [String: Any] {
        let props: [String: Any] = [
            AutoCaptureConstants.tabName: name,
            AutoCaptureConstants.tabIndex: index
        ]
        return props
    }

    /// Builds the `internalProperties` dictionary for an interaction event.
    /// Always includes the raw interaction type and the UI framework tag.
    func buildInternalProperties(for interactionType: InteractionType) -> [String: Any] {
        return [AutoCaptureConstants.rawInteractionType: interactionType.rawValue]
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

    /// UIKit production behavior is preserved: screen events keep using the controller class.
    /// SwiftUI uses the resolved logical screen name when available so initial screen capture,
    /// fake reload, and dedupe all key off the same screen identity.
    func screenEventIdentity(screenClass: String, payload: ScreenTrackingPayload) -> String {
        guard config.appFramework == .SwiftUI else { return screenClass }
        let logicalName = payload.currentScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        return logicalName.isEmpty ? screenClass : logicalName
    }

}

// swiftlint:enable file_length
