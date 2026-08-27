//
//  UIViewController+Extensions.swift
//  Userpilot
//
//  Created by Motasem Hamed on 05/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIViewController+Extensions provides automatic screen tracking functionality
//  through method swizzling and screen name resolution.
//

import UIKit

// MARK: - Internal

/// Extension providing automatic screen tracking for UIViewController
internal extension UIViewController {

    // MARK: Swizzled Methods

    /// Swizzled viewWillAppear that captures auto screen events
    /// - Parameter animated: Whether the appearance is animated
    @objc
    func userpilot__viewWillAppear(animated: Bool) {
        userpilot__viewWillAppear(animated: animated)
        // Per-instance stop is enforced in `AutoCaptureCoordinater.trackScreen`,
        // which `captureScreenIfNeeded()` routes to after resolving the owner.
        captureScreenIfNeeded()
    }

    // MARK: Screen Capture

    /// `true` when the bundle that defines `cls` is an Apple system framework (`com.apple.*`).
    private func isAppleSystemFrameworkBundle(_ bundle: Bundle) -> Bool {
        guard let id = bundle.bundleIdentifier?.lowercased() else { return false }
        return id.hasPrefix("com.apple.")
    }

    /// Skip screen capture for classes implemented in Apple OS frameworks (UIKit, SwiftUI, SpringBoard, …).
    /// Exception: `UIAlertController` (`dialog_presented`).
    private func isOSProvidedViewControllerToSkip() -> Bool {
        if self is UIAlertController { return false }
        return isAppleSystemFrameworkBundle(Bundle(for: type(of: self)))
    }

    /// Built-in UIKit container types (also skips app subclasses, e.g. `class MyNav: UINavigationController`).
    private func isUIKitSystemContainerViewController() -> Bool {
        self is UINavigationController
            || self is UITabBarController
            || self is UISplitViewController
            || self is UIPageViewController
    }

    /// Filters out Apple system VCs in SwiftUI mode unless they are the SwiftUI hosting screen boundary.
    ///
    /// Unlike `isOSProvidedViewControllerToSkip()` (which skips ALL Apple-bundle VCs),
    /// this method keeps real SwiftUI HostingControllers and any app-owned VC that represents a real screen.
    private func isSwiftUISystemNoisyViewController() -> Bool {
        let cls = type(of: self)
        let className = NSStringFromClass(cls)
        let bundle = Bundle(for: cls)

        // 1. Always KEEP app-bundle VCs — they are user screens regardless of name.
        guard isAppleSystemFrameworkBundle(bundle) else { return false }

        // 2. Always KEEP UIAlertController — tracked as `dialog_presented`.
        if self is UIAlertController { return false }

        // 3. Some Apple internals include "HostingController" in their class name,
        //    but are keyboard/emoji/secure scene noise rather than app screen boundaries.
        let noisyHostingControllerFragments: [String] = [
            "_UISceneHostingViewController",
            "SecureHostingController"
        ]

        if noisyHostingControllerFragments.contains(where: { className.contains($0) }) {
            return true
        }

        // 4. KEEP normal HostingControllers — they are the SwiftUI screen boundary.
        //    Covers: UIHostingController, _UIHostingController, SwiftUI.AnyHostingController, etc.
        if className.contains("HostingController") { return false }

        // 5. Everything else from Apple in SwiftUI mode is system chrome/noise
        //    (keyboard, emoji/sticker search, edit overlays, context menus, etc.).
        return true
    }

    // MARK: Private

    // The complexity here is the sum of guards that filter out internal/system
    // VCs, untracked screens, and async SwiftUI hosting controllers. Each branch
    // is straight-line and individually trivial; collapsing them would harm
    // readability without removing any logic.
    // swiftlint:disable:next cyclomatic_complexity
    private func captureScreenIfNeeded() {
        guard Userpilot.isInitialized else { return }
        guard view.window?.isUserpilotWindow != true else { return }

        // Resolve the owning Userpilot instance from this view controller. In a
        // single-instance integration this is always the default instance and
        // matches the previous global fallback lookup. In multi-instance the
        // resolution honours the bundle / window / VC-class scope of each instance.
        guard let owningInstance = InstanceResolver.shared.target(forViewController: self) else {
            return
        }
        let config = owningInstance.config
        guard config.enableScreenAutoCapture else { return }

        guard !isUIKitSystemContainerViewController() else { return }

        if config.appFramework == .SwiftUI {
            // ✅ SwiftUI path: filter noisy system VCs, keep HostingControllers
            if isSwiftUISystemNoisyViewController() {
                return
            }
        } else {
            // ✅ UIKit path (also used when framework is not yet detected)
            if isOSProvidedViewControllerToSkip() {
                return
            }
        }

        let untracked =
            objc_getAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey) as? Bool ?? false
        guard !untracked else { return }

        guard !userpilotIgnoreScreen else { return }

        // SwiftUI hosting controllers: defer capture to the next run loop so
        // ScreenNameBridge (UIViewRepresentable) has time to mount and propagate
        // the screen name set via .userpilotScreenName(). Without this,
        // viewWillAppear fires before the bridge UIView is created, causing the
        // first screen event to miss the custom name.
        if config.appFramework == .SwiftUI,
           screenClassName.contains("HostingController") {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                owningInstance.autoCaptureCoordinator.trackScreen(buildScreenTrackingPayload(config: config))
            }
        } else {
            owningInstance.autoCaptureCoordinator.trackScreen(buildScreenTrackingPayload(config: config))
        }
    }

    // MARK: Payload Building

    private func buildScreenTrackingPayload(config: Userpilot.Config) -> ScreenTrackingPayload {

        if let alert = self as? UIAlertController {
            let dialogText = alert.userpilotDialogText()
            var payload = ScreenTrackingPayload(
                currentScreen: resolvedScreenNameForCapture(),
                screenClass: screenClassName,
                screenType: screenType,
                navigationTitle: config.enableScreenTitleCapture ? resolveNavigationTitle() : nil,
                isUserpilotContainerClass: type(of: self).isUserpilotContainerClass,
                vcAccessibilityIdentifier: view.accessibilityIdentifier,
                vcAccessibilityLabel: view.accessibilityLabel,
                isDialogPresentation: true,
                alertTitle: dialogText.title,
                alertMessage: dialogText.message
            )
            payload.appFramework = config.appFramework
            return payload
        }

        var payload = ScreenTrackingPayload(
            currentScreen: resolvedScreenNameForCapture(),
            screenClass: screenClassName,
            screenType: screenType,
            navigationTitle: config.enableScreenTitleCapture ? resolveNavigationTitle() : nil,
            isUserpilotContainerClass: type(of: self).isUserpilotContainerClass,
            vcAccessibilityIdentifier: view.accessibilityIdentifier,
            vcAccessibilityLabel: view.accessibilityLabel
        )
        payload.appFramework = config.appFramework
        return payload
    }
}

// MARK: - Dialog Text Redaction

internal extension UIAlertController {

    /// The title / message published as the text of the `view_presented` autocapture event.
    ///
    /// They are captured text, so they follow the same policy as any other captured text:
    /// omitted when the owning instance's `enableInteractionTextCapture` is off, replaced with the
    /// redaction placeholder when `userpilotRedactText` is set on the alert's responder chain.
    /// `nil` values stay `nil`, so policy never adds a property that would not have been published.
    func userpilotDialogText() -> (title: String?, message: String?) {
        if view.isInteractionTextCaptureDisabled() {
            return (nil, nil)
        }
        if view.hasUserpilotRedactTextOptIn() {
            return (
                title == nil ? nil : Constants.AutoCapture.reductText,
                message == nil ? nil : Constants.AutoCapture.reductText
            )
        }
        return (title, message)
    }
}
