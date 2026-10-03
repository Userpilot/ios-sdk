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
    func trackScreen(_ screen: ScreenTrackingPayload)

    /// Temporarily suppresses automatic screen events caused by SDK-owned UI dismissal.
    func suppressScreenAutoCaptureAfterSDKContent()

    /// Publishes a `mobile_autocapture` event for tab-bar selection.
    func handleTabSelected(name tabName: String, index tabIndex: Int, screenClass: String)

    /// Publishes a structured interaction (control, cell, text input, etc.) as `mobile_autocapture`.
    func handleInteractionEvent(_ interaction: InteractionPayload)

    /// Publishes window-level tap properties as `mobile_autocapture` when they pass noise filtering.
    func handleClickTracked(_ properties: [String: Any])

    /// Auto capture screen events from wrappers
    func trackExternalAutoCaptureScreen(_ screen: String)

    /// Auto capture interactions events from wrappers
    func trackExternalAutoCaptureEvent(_ eventName: String, _ properties: Payload)

    /// `true` when capture is paused for this instance via `stopAutoCapture()`.
    var isStopped: Bool { get }

    /// Pauses automatic screen + interaction capture for THIS instance only;
    /// other instances in the process keep capturing. Reversed by `resumeAutoCapture()`.
    func stopAutoCapture()

    /// Resumes automatic capture for THIS instance after `stopAutoCapture()`.
    func resumeAutoCapture()
}

// Responsible for automatically capturing screen transitions and user interaction events
// in UIKit-based apps. Works via method swizzling and notification observation.
// All captured events are enriched with screen context and app metadata before publishing.

internal class AutoCaptureCoordinater {

    // MARK: - Dependencies

    private let analyticsPublisher: AnalyticsPublishing
    private let config: Userpilot.Config
    private let screenNameTracker: ScreenNameTracking

    /// Process-wide instance registry, injected so the external-source forwarding
    /// path can resolve the default instance without touching `Registry.shared`.
    private let registry: InstanceRegistering

    /// Protects pending SwiftUI screen state and SDK-content dismissal suppression.
    private let screenCaptureStateLock = NSLock()

    /// The identity is checked again on main so suppression or stop can invalidate queued delivery.
    private var pendingSwiftUIScreenID: UUID?

    /// DelayUtils synchronizes scheduling and cancellation; callbacks run on main.
    private let swiftUIScreenDelay = DelayUtils()

    /// Ignore automatic screen events until this date, used after SDK content fake reloads.
    private var suppressScreenCaptureUntil: Date?

    /// Small delay that lets SwiftUI emit nested hosting controller appearances before we publish.
    private let swiftUIScreenCoalescingDelay: TimeInterval = 0.08

    /// Dismissing SDK content can re-fire the underlying app's viewWillAppear chain.
    private let sdkContentDismissalSuppressionInterval: TimeInterval = 0.8

    /// Per-instance stop/resume gate. When `true`, this instance records no screen
    /// or interaction events until `resumeAutoCapture()` is called; other instances
    /// are unaffected.
    private let stoppedState = AtomicReference<Bool>(false)

    // MARK: - Computed Helpers

    /// Captures wrapper context once so reset or another screen cannot split the presence check and read.
    private var currentScreenDictionaryForWrappers: [String: Any]? {
        guard let screen = screenNameTracker.getCurrentPayload() else { return nil }
        return [Constants.AutoCapture.screenTitle: screen.screenClass]
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
        self.registry = container.resolve(InstanceRegistering.self)

        guard !config.isWrapperSDK else { return }

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
    /// This is the main gate for automatic screen capture. It drops events while this instance's
    /// autocapture is stopped, ignores the short SDK-content dismissal window, routes dialogs to
    /// dialog capture, and coalesces SwiftUI hosting-controller appearances before publishing.
    ///
    /// - Parameter screen: The resolved screen payload for the appearing view controller.
    func trackScreen(_ screen: ScreenTrackingPayload) {
        tryCatch {
            guard !isStopped else { return }
            guard !shouldSuppressScreenAutoCapture else { return }

            // Interaction autocapture debounces text-field / text-view changes, so a change the
            // user made right before navigating would otherwise be published after this screen
            // event and attributed to the new screen. Flush pending captures first (same as the
            // manual `Userpilot.screen(_:)` path).
            if config.enableInteractionAutoCapture {
                InteractionEventCache.flushPendingInteractions()
            }

            if screen.isDialogPresentation {
                publishDialogPresentedAutocapture(from: screen)
                return
            }

            if shouldCoalesceSwiftUIScreen(screen) {
                coalesceSwiftUIScreen(screen)
                return
            }

            publishScreen(screen)
        }
    }

    /// Starts a short suppression window after SDK-owned content has been dismissed.
    ///
    /// Closing Userpilot content can cause the underlying app view-controller tree to receive fresh
    /// `viewWillAppear` callbacks. Those callbacks do not represent client navigation, so this method
    /// cancels any pending SwiftUI coalesced screen event and suppresses automatic screen capture
    /// briefly while UIKit/SwiftUI settles back to the already tracked screen.
    func suppressScreenAutoCaptureAfterSDKContent() {
        screenCaptureStateLock.withLock {
            pendingSwiftUIScreenID = nil
            swiftUIScreenDelay.cancelDelay()
            suppressScreenCaptureUntil = Date().addingTimeInterval(sdkContentDismissalSuppressionInterval)
        }
    }

    // MARK: - Tab Tracking

    func handleTabSelected(name tabName: String, index tabIndex: Int, screenClass: String) {
        guard isInteractionTrackingActive else { return }

        let screen = screenNameTracker.getCurrentPayload()
        let interactionType = InteractionType.tabSelected
        var properties = buildTabProperties(name: tabName, index: tabIndex)
        let internalProps = buildInternalProperties(for: interactionType)
        properties.merge(internalProps) { (_, new) in new }

        // Attach a minimal hierarchy leaf for the selected tab content, mirroring the
        // `view_presented` dialog path: `<TabContentVC>:attr__index="<tabIndex>"`. The
        // tracked screen class is appended downstream as `;<ScreenName>`. As with the
        // dialog hierarchy this is intentionally shallow — it identifies the selected
        // tab's content controller rather than a full leaf-to-root view walk.
        let leaf = screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        if !leaf.isEmpty {
            let escaped = leaf.replacingOccurrences(of: "\"", with: "\\\"")
            properties[Constants.AutoCapture.hierarchy] = "\(escaped):attr__index=\"\(tabIndex)\""
            appendScreenNameSegmentToHierarchy(&properties, screen: screen)
        }

        let event = makeEvent(
            type: EventType.autoCaptureEvent,
            properties: properties,
            screen: screen,
            interactionEventName: interactionType.toInteractionEventType().rawValue
        )

        publishWithForwarding(event)
    }

    // MARK: - Interaction Tracking

    func handleInteractionEvent(_ interaction: InteractionPayload) {
        publishInteractionPayload(interaction)
    }

    func handleClickTracked(_ properties: [String: Any]) {
        guard isInteractionTrackingActive else { return }
        guard shouldPublishWindowLevelTouch(properties) else { return }
        guard let payload = interactionPayload(fromWindowClick: properties) else { return }
        publishInteractionPayload(payload)
    }

    // MARK: - Stop / Resume (per instance)

    /// `true` while this instance's capture is paused. Thread-safe.
    var isStopped: Bool {
        stoppedState.value
    }

    func stopAutoCapture() {
        stoppedState.value = true
        screenCaptureStateLock.withLock {
            pendingSwiftUIScreenID = nil
            swiftUIScreenDelay.cancelDelay()
        }
    }

    func resumeAutoCapture() {
        stoppedState.value = false
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
        screenCaptureStateLock.withLock {
            guard let suppressScreenCaptureUntil else { return false }
            if Date() < suppressScreenCaptureUntil { return true }
            self.suppressScreenCaptureUntil = nil
            return false
        }
    }

    /// `true` when interaction tracking is enabled for this instance and not paused
    /// at runtime via `stopAutoCapture()`.
    var isInteractionTrackingActive: Bool {
        !isStopped && config.enableInteractionAutoCapture
    }

    /// Returns `true` when a screen payload should be delayed and coalesced for SwiftUI.
    ///
    /// SwiftUI can emit multiple hosting-controller appearances for one visible screen, such as a
    /// `NavigationStackHostingController` followed immediately by a `TabHostingController`.
    /// Delaying these briefly lets the deepest/latest hosting controller win.
    ///
    /// - Parameter screen: The screen payload being considered for immediate publication.
    /// - Returns: `true` when the screen is a SwiftUI hosting-controller screen.
    func shouldCoalesceSwiftUIScreen(_ screen: ScreenTrackingPayload) -> Bool {
        config.appFramework == .SwiftUI && screen.screenClass.contains("HostingController")
    }

    /// Delays publication of a SwiftUI hosting screen so duplicate parent/child appearances collapse.
    ///
    /// Each new SwiftUI hosting payload replaces the previous pending payload and cancels the previous
    /// work item. After `swiftUIScreenCoalescingDelay`, the latest payload is published unless SDK
    /// dismissal suppression became active meanwhile.
    ///
    /// - Parameter screen: The latest SwiftUI hosting-controller screen payload.
    func coalesceSwiftUIScreen(_ screen: ScreenTrackingPayload) {
        screenCaptureStateLock.withLock {
            guard !isStopped else { return }
            let identifier = UUID()
            pendingSwiftUIScreenID = identifier
            swiftUIScreenDelay.delayAction(delayTime: swiftUIScreenCoalescingDelay) { [weak self] in
                self?.publishPendingSwiftUIScreenIfAllowed(screen, identifier: identifier)
            }
        }
    }

    /// Claims the coalesced payload under the lock and publishes on main after releasing it.
    /// An expired callback must not consume a newer screen or publish after stop/suppression.
    func publishPendingSwiftUIScreenIfAllowed(_ screen: ScreenTrackingPayload, identifier: UUID) {
        let shouldPublish = screenCaptureStateLock.withLock {
            guard pendingSwiftUIScreenID == identifier else { return false }
            pendingSwiftUIScreenID = nil
            if let suppressScreenCaptureUntil {
                if Date() < suppressScreenCaptureUntil { return false }
                self.suppressScreenCaptureUntil = nil
            }
            return true
        }
        guard shouldPublish, !isStopped else { return }
        publishScreen(screen)
    }

    /// Publishes a screen event immediately after updating the current screen context.
    ///
    /// This method is the shared publication path for UIKit screens and coalesced SwiftUI screens.
    /// It updates `ScreenNameTracker`, builds the backend event identity, attaches the full screen
    /// dictionary, and forwards the event to `AnalyticsPublishing`.
    ///
    /// - Parameter screen: The screen payload to persist and publish.
    func publishScreen(_ screen: ScreenTrackingPayload) {
        let previousScreen = screenNameTracker.getCurrentPayload()
        var screen = screen
        if config.appFramework == .SwiftUI {
            screen.screenNameMatchesPreviousScreen = screenNameMatchesPreviousScreen(
                screen,
                previousScreen: previousScreen
            )
        }

        screenNameTracker.updateScreen(with: screen)

        let event = makeEvent(
            type: EventType.screen(screenEventIdentity(screenClass: screen.screenClass, screen: screen)),
            properties: screen.toDictionary(),
            screen: screen
        )

        publishWithForwarding(event)
    }

    /// Returns whether the SwiftUI screen name/title matches the previous screen context.
    ///
    /// This is diagnostic metadata for cases where SwiftUI/NavigationStack exposes a stale UIKit
    /// title. For example, a destination without its own `.navigationTitle` may resolve to the
    /// previous screen's navigation title.
    func screenNameMatchesPreviousScreen(
        _ screen: ScreenTrackingPayload,
        previousScreen: ScreenTrackingPayload?
    ) -> Bool {
        guard config.appFramework == .SwiftUI,
              let previousScreen
        else { return false }

        let currentScreen = screen.currentScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentScreen.isEmpty else { return false }

        let previousValues = [
            previousScreen.currentScreen,
            previousScreen.navigationTitle
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
        Constants.AutoCapture.swiftUIView
    ]

    /// SwiftUI framework-internal layout / hosting scaffolding classes that surface as the resolved
    /// leaf when a tap lands on container background rather than an interactive element. These never
    /// carry developer-meaningful text/label/id, so a tap resolving to one of them with no metadata is
    /// a dead click. The non-underscore names below are not caught by `windowTouchIsPrivateUIKitElementType`
    /// (which only handles `_UI…` / `_NS…`). They are matched only after the metadata check, so taps on
    /// these classes that *do* carry text/accessibility info are still published unchanged.
    private static let swiftUIStructuralContainerTypes: Set<String> = [
        "PlatformGroupContainer",
        "PlatformContainer",
        "PlatformViewHost",
        "HostingView",
        "HostingScrollView"
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

    /// SwiftUI scaffolding leaf (hosting / platform container) with no metadata — a dead click.
    ///
    /// Only consulted for SwiftUI-configured apps and only after `windowTouchHasMetadata` has already
    /// returned `false`, so this can never suppress a tap that resolved any text / accessibility signal.
    /// These class names are SwiftUI-exclusive, so UIKit capture is unaffected.
    private func windowTouchIsSwiftUIStructuralContainer(_ elementType: String) -> Bool {
        guard config.appFramework == .SwiftUI else { return false }
        if Self.swiftUIStructuralContainerTypes.contains(elementType) { return true }
        // SwiftUI's private hosting wrappers embed these stable, framework-internal substrings.
        if elementType.contains("HostingView") || elementType.contains("HostingScrollView") {
            return true
        }
        return false
    }

    /// True when any identifying string is present (including redacted placeholder).
    private func windowTouchHasMetadata(_ properties: [String: Any]) -> Bool {
        let keys: [String] = [
            Constants.AutoCapture.targetText,
            Constants.AutoCapture.accessibilityLabel,
            Constants.AutoCapture.accessibilityIdentifier
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
        guard let elementType = properties[Constants.AutoCapture.targetClass] as? String else {
            return false
        }
        if windowTouchIsPrivateUIKitElementType(elementType) {
            return false
        }
        let hierarchy = properties[Constants.AutoCapture.hierarchy] as? String
        if windowTouchIsSystemKeyboardChrome(elementType: elementType, hierarchy: hierarchy) {
            return false
        }
        if windowTouchHasMetadata(properties) {
            return true
        }
        if windowTouchIsSwiftUIStructuralContainer(elementType) {
            return false
        }
        if Self.structuralWindowTouchElementTypes.contains(elementType) {
            return false
        }
        return true
    }

    /// Maps window `sendEvent` dictionaries into the same payload shape as other interaction paths.
    private func interactionPayload(fromWindowClick properties: [String: Any]) -> InteractionPayload? {
        guard let elementType = properties[Constants.AutoCapture.targetClass] as? String else {
            return nil
        }
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: elementType
        )
        if let targetText = properties[Constants.AutoCapture.targetText] as? String {
            payload.elementText = targetText
        }
        if let accessibilityLabel = properties[Constants.AutoCapture.accessibilityLabel] as? String {
            payload.accessibilityLabel = accessibilityLabel
        }
        if let targetResourceId = properties[Constants.AutoCapture.accessibilityIdentifier] as? String {
            payload.accessibilityIdentifier = targetResourceId
        }
        payload.hierarchy = properties[Constants.AutoCapture.hierarchy] as? String
        return payload
    }

    /// Publishes an interaction using the same merge rules as `handleInteractionEvent`.
    private func publishInteractionPayload(_ interaction: InteractionPayload) {
        guard isInteractionTrackingActive else { return }
        publishAutoCaptureInteractionPayload(interaction)
    }

    /// When hierarchy was built with no owning VC, the root is
    /// `unknownScreenHierarchyPlaceholder`; swap in the tracked screen class.
    private func replaceUnknownScreenPlaceholderInHierarchy(
        _ properties: inout [String: Any],
        screen: ScreenTrackingPayload?
    ) {
        let placeholder = Constants.AutoCapture.unknownScreenHierarchyPlaceholder
        guard var hierarchy = properties[Constants.AutoCapture.hierarchy] as? String,
              hierarchy.contains(placeholder) else { return }
        guard let screenClass = screen?.screenClass,
              !screenClass.isEmpty else { return }
        hierarchy = hierarchy.replacingOccurrences(of: placeholder, with: screenClass)
        properties[Constants.AutoCapture.hierarchy] = hierarchy
    }

    /// Appends `;SCREEN_NAME` to the view hierarchy using `screenNameTracker`.
    private func appendScreenNameSegmentToHierarchy(
        _ properties: inout [String: Any],
        screen: ScreenTrackingPayload?
    ) {
        guard var hierarchy = properties[Constants.AutoCapture.hierarchy] as? String,
              !hierarchy.isEmpty,
              let payload = screen else { return }

        let screenClass = payload.screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !screenClass.isEmpty else { return }

        let escaped = screenClass.replacingOccurrences(of: "\"", with: "\\\"")
        hierarchy += ";\(escaped)"
        properties[Constants.AutoCapture.hierarchy] = hierarchy
    }

    /// Shared `mobile_autocapture` merge and publish. `publishInteractionPayload`
    /// applies the interaction guard first; dialog events call this directly.
    private func publishAutoCaptureInteractionPayload(_ interaction: InteractionPayload) {
        let screen = screenNameTracker.getCurrentPayload()
        var properties: [String: Any] = [:]
        properties.merge(interaction.toDictionary()) { _, new in new }
        var internalProps = buildInternalProperties(for: interaction.interactionType)
        internalProps.merge(interaction.toSourceDictionary()) { _, new in new }
        properties.merge(internalProps) { _, new in new }
        replaceUnknownScreenPlaceholderInHierarchy(&properties, screen: screen)
        appendScreenNameSegmentToHierarchy(&properties, screen: screen)

        let event = makeEvent(
            type: EventType.autoCaptureEvent,
            properties: properties,
            screen: screen,
            interactionEventName: interaction.interactionType.toInteractionEventType().rawValue
        )
        publishWithForwarding(event)
    }

    /// Publishes [event] to this instance's own publisher, then — when this is a
    /// non-default instance and the resolved default (client app) instance opted in
    /// via `Config.allowReceiveEventsFromExternalSource` — forwards the same event to
    /// the default instance so the host app becomes aware of vendor-owned autocapture
    /// events.
    func publishWithForwarding(_ event: Event) {
        analyticsPublisher.publish(event)
        forwardToDefaultIfNeeded(event)
    }

    private func forwardToDefaultIfNeeded(_ event: Event) {
        guard let defaultInstance = registry.default else { return }
        // This instance is the default → the event is already its own; do not self-forward.
        guard defaultInstance.config.token != config.token else { return }
        guard defaultInstance.config.allowReceiveEventsFromExternalSource else { return }
        defaultInstance.resolveAnalyticsPublisher().publish(event)
    }

    /// `UIAlertController` is not emitted as a screen view; send
    /// `dialog_presented` with title/message when screen autocapture runs.
    private func publishDialogPresentedAutocapture(from screen: ScreenTrackingPayload) {
        guard config.enableInteractionAutoCapture else { return }
        var payload = InteractionPayload(
            interactionType: .viewPresented,
            elementType: Constants.AutoCapture.elementTypeUIAlertController
        )
        payload.dialogTitle = screen.alertTitle
        payload.dialogMessage = screen.alertMessage

        // Build a synthetic hierarchy leaf for the dialog so the published event carries
        // `hierarchy = "UIAlertController:attr__index=\"0\";<UnderlyingScreen>"`.
        // The underlying screen class is appended downstream by
        // `appendScreenNameSegmentToHierarchy` (the screen tracker still holds the screen
        // the dialog was presented over because dialog payloads short-circuit before
        // `updateScreen(...)` is called).
        let dialogClass = screen.screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        let leaf = dialogClass.isEmpty
            ? Constants.AutoCapture.elementTypeUIAlertController
            : dialogClass.replacingOccurrences(of: "\"", with: "\\\"")
        payload.hierarchy = "\(leaf):attr__index=\"0\""

        publishAutoCaptureInteractionPayload(payload)
    }

    // MARK: Dictionary Builders

    /// Builds the properties dictionary for a tab-selection event.
    func buildTabProperties(name: String, index: Int) -> [String: Any] {
        let props: [String: Any] = [
            Constants.AutoCapture.tabName: name,
            Constants.AutoCapture.tabIndex: index
        ]
        return props
    }

    /// Builds the `internalProperties` dictionary for an interaction event.
    /// Always includes the raw interaction type and the UI framework tag.
    func buildInternalProperties(for interactionType: InteractionType) -> [String: Any] {
        var result: [String: String] = [
            Constants.AutoCapture.rawInteractionType: interactionType.rawValue
        ]
        if let framework = config.appFramework?.rawValue {
            result[Constants.AutoCapture.uiFramework] = framework
        }
        return result
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
        screen: ScreenTrackingPayload?,
        interactionEventName: String? = nil
    ) -> Event {
        Event(
            type: type,
            properties: properties,
            screen: screen.map { ScreenNameTracker.buildScreenDictionaryForEvent(from: $0) },
            interactionEventName: interactionEventName
        )
    }

    /// UIKit production behavior is preserved: screen events keep using the controller class.
    /// SwiftUI uses the resolved logical screen name when available so initial screen capture,
    /// fake reload, and dedupe all key off the same screen identity.
    func screenEventIdentity(screenClass: String, screen: ScreenTrackingPayload) -> String {
        guard config.appFramework == .SwiftUI else { return screenClass }
        let logicalName = screen.currentScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        return logicalName.isEmpty ? screenClass : logicalName
    }

}

// MARK: Auto capture wrappers APIs

extension AutoCaptureCoordinater {
    /// Auto capture screen events from wrappers
    func trackExternalAutoCaptureScreen(_ title: String) {
        guard config.isWrapperSDK else { return }
        let screenPayload = ScreenTrackingPayload(screenTitle: title)
        screenNameTracker.updateScreen(with: screenPayload)
        let event = Event(
            type: .screen(title),
            properties: [Constants.AutoCapture.source: Constants.AutoCapture.autoCaptureSourceValue]
        )
        analyticsPublisher.publish(event)

    }

    /// Auto capture interactions events from wrappers
    func trackExternalAutoCaptureEvent(_ eventName: String, _ properties: Payload) {
        guard config.isWrapperSDK else { return }
        let event = Event(
            type: EventType.autoCaptureEvent,
            properties: properties,
            screen: currentScreenDictionaryForWrappers,
            interactionEventName: eventName
        )
        analyticsPublisher.publish(event)
    }
}
// swiftlint:enable file_length
