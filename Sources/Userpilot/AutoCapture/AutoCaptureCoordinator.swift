//
//  AutoCaptureCoordinator.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  AutoCaptureCoordinator manages automatic screen and interaction tracking for UIKit applications,
//  handling screen transitions, control interactions, table/collection view selections, and text input.
//

import Foundation
import UIKit

/// Per-instance entry points for native hooks and wrappers to publish captured screens and interactions.
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

/// Coordinates capture gates, screen context, and delivery for one SDK instance.
/// Payload models own field conversion; native hooks retain responsibility for redaction.
/// Screen coalescing and suppression share a lock; publishing occurs after releasing it.
internal class AutoCaptureCoordinator {

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

    /// Pauses this instance without disabling capture for other registered instances.
    private let stoppedState = AtomicReference<Bool>(false)

    /// Resolves instance dependencies and installs the configured native hooks; wrappers provide their own events.
    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)
        self.registry = container.resolve(InstanceRegistering.self)

        guard !config.isWrapperSDK else { return }

        // Screen tracking supplies context for subsequent interactions.
        if config.enableScreenAutoCapture {
            setupAutoCaptureScreens()
            config.logger.info("📊 Automatic UIKit screen tracking enabled")
        }

        if config.enableInteractionAutoCapture {
            setupAutoCaptureInteractions()
            config.logger.info("📊 Automatic UIKit interaction tracking enabled")
        }
    }

    /// Installs view-controller lifecycle and tab-selection hooks.
    private func setupAutoCaptureScreens() {
        AutoCaptureSwizzler.swizzleUIKitScreenTracking()
        AutoCaptureSwizzler.swizzleTabBarTracking()
    }

    /// Installs window/control/picker hooks and text-change notifications.
    private func setupAutoCaptureInteractions() {
        AutoCaptureSwizzler.swizzleClickTracking()
        AutoCaptureSwizzler.swizzleApplicationSendAction()
        AutoCaptureSwizzler.swizzlePickerViewDelegate()
        AutoCaptureSwizzler.registerTextFieldNotifications()
        AutoCaptureSwizzler.registerTextViewNotifications()
    }
}

extension AutoCaptureCoordinator: AutoCaptureCoordinating {

    // MARK: - Screen Tracking

    /// Applies stop/suppression gates, flushes interactions, then routes dialogs or native screens.
    func trackScreen(_ screen: ScreenTrackingPayload) {
        tryCatch {
            guard !isStopped else { return }
            guard !shouldSuppressScreenAutoCapture else { return }

            // Flush debounced text changes before navigation can attribute them to the new screen.
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

    /// Cancels pending SwiftUI delivery and ignores appearances caused by SDK content dismissal.
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
        let properties = interactionType.buildTabProperties(
            name: tabName,
            index: tabIndex,
            screenClass: screenClass,
            screen: screen,
            framework: config.appFramework
        )

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
        guard isInteractionTrackingActive else { return }
        publishAutoCaptureEvent(interaction)
    }

    func handleClickTracked(_ properties: [String: Any]) {
        guard isInteractionTrackingActive else { return }
        guard WindowTouchFilter.shouldPublishWindowLevelTouch(properties, config: config) else { return }
        guard let payload = InteractionPayload.fromWindowClick(properties) else { return }
        handleInteractionEvent(payload)
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

private extension AutoCaptureCoordinator {

    /// Clears an expired SDK-dismissal suppression window under the shared screen lock.
    var shouldSuppressScreenAutoCapture: Bool {
        screenCaptureStateLock.withLock {
            guard let suppressScreenCaptureUntil else { return false }
            if Date() < suppressScreenCaptureUntil { return true }
            self.suppressScreenCaptureUntil = nil
            return false
        }
    }

    /// Applies this instance's runtime stop and configured interaction gates.
    var isInteractionTrackingActive: Bool {
        !isStopped && config.enableInteractionAutoCapture
    }

    /// SwiftUI parent/child hosting appearances are coalesced so the latest resolved screen wins.
    func shouldCoalesceSwiftUIScreen(_ screen: ScreenTrackingPayload) -> Bool {
        config.appFramework == .SwiftUI && screen.screenClass.contains("HostingController")
    }

    /// Replaces the pending SwiftUI screen; stop or SDK dismissal can invalidate its delivery.
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

    /// Updates screen context and publishes the native screen using that same payload.
    func publishScreen(_ screen: ScreenTrackingPayload) {
        let previousScreen = screenNameTracker.getCurrentPayload()
        var screen = screen
        if config.appFramework == .SwiftUI {
            screen.screenNameMatchesPreviousScreen = screen.matchesPreviousScreen(
                previousScreen, framework: config.appFramework
            )
        }

        screenNameTracker.updateScreen(with: screen)

        let event = makeEvent(
            type: EventType.screen(screen.screenEventIdentity(framework: config.appFramework)),
            properties: screen.toDictionary(),
            screen: screen
        )

        publishWithForwarding(event)
    }

    /// Keeps target → internal → source overwrite order, then enriches hierarchy from one screen.
    /// `handleInteractionEvent` applies the interaction guard; dialog capture uses its own gate.
    private func publishAutoCaptureEvent(_ interaction: InteractionPayload) {
        let screen = screenNameTracker.getCurrentPayload()
        let properties = interaction.buildEventProperties(screen: screen, framework: config.appFramework)

        let event = makeEvent(
            type: EventType.autoCaptureEvent,
            properties: properties,
            screen: screen,
            interactionEventName: interaction.interactionType.toInteractionEventType().rawValue
        )
        publishWithForwarding(event)
    }

    /// Publishes locally first, then forwards directly to an opted-in default instance without re-routing.
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
    /// `view_presented` with title/message when screen autocapture runs.
    private func publishDialogPresentedAutocapture(from screen: ScreenTrackingPayload) {
        guard config.enableInteractionAutoCapture else { return }
        let payload = InteractionPayload.fromDialog(screen)
        publishAutoCaptureEvent(payload)
    }

    /// Creates an event using the supplied screen snapshot; analytics owns decoration.
    func makeEvent(
        type: EventType,
        properties: [String: Any],
        screen: ScreenTrackingPayload?,
        interactionEventName: String? = nil
    ) -> Event {
        Event(
            type: type,
            properties: properties,
            screen: screen.map { $0.toEventDictionary() },
            interactionEventName: interactionEventName
        )
    }

}

// MARK: Auto capture wrappers APIs

extension AutoCaptureCoordinator {
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
            screen: screenNameTracker.getCurrentPayload()?.toWrapperEventDictionary(),
            interactionEventName: eventName
        )
        analyticsPublisher.publish(event)
    }
}
