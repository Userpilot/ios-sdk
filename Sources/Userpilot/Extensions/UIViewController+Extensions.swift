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
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
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

    /// Filters out noisy Apple system VCs in SwiftUI mode (keyboard, menus, cursors, etc.)
    /// while intentionally KEEPING HostingControllers and any app-owned VC that represents a real screen.
    ///
    /// Unlike `isOSProvidedViewControllerToSkip()` (which skips ALL Apple-bundle VCs),
    /// this method only skips VCs whose class names are known system noise.
    private func isSwiftUISystemNoisyViewController() -> Bool {
        let cls = type(of: self)
        let className = NSStringFromClass(cls)
        let bundle = Bundle(for: cls)

        // 1. Always KEEP app-bundle VCs — they are user screens regardless of name.
        guard isAppleSystemFrameworkBundle(bundle) else { return false }

        // 2. Always KEEP HostingControllers — they are the SwiftUI screen boundary.
        //    Covers: UIHostingController, _UIHostingController, SwiftUI.AnyHostingController, etc.
        if className.contains("HostingController") { return false }

        // 3. Always KEEP UIAlertController — tracked as `dialog_presented`.
        if self is UIAlertController { return false }

        // 4. Skip known noisy Apple-internal system VCs by name fragment.
        //    Add to this list as you discover new noisy classes in the wild.
        let noisyFragments: [String] = [
            "UICursorAccessory",         // _UICursorAccessoryViewController
            "UIInputWindowController",   // keyboard host window
            "UISystemKeyboardDock",      // keyboard dock
            "UIKeyboardCamera",          // keyboard camera integration
            "PrewarmingViewController",  // system prewarming
            "SecureHostingController",   // system-internal secure host (e.g. Genmoji)
            "UIMultiscriptCandidate",    // multiscript keyboard candidate VC
            "UICompatibilityInput",      // legacy input VC
            "_UIContextMenuActionsOnly", // context menu action sheet
            "UIKeyboardHUD",             // keyboard HUD overlays
            "UIEditMenu",                // edit menu (copy/paste)
            "UISystemInputAssistant",    // input assistant bar
            "UITextEffects",             // text effect overlays
            "UIApplicationRotation",     // rotation placeholder VC
            "UIRemoteKeyboard",          // remote keyboard extension
            "UISearchSuggestion"        // search suggestion overlay
        ]

        return noisyFragments.contains { className.contains($0) }
    }

    // MARK: Private

    private func captureScreenIfNeeded() {
        guard Userpilot.isInitialized,
              Userpilot.shared.config.enableScreenAutoCapture
        else { return }

        guard !isUIKitSystemContainerViewController() else { return }

        if Userpilot.shared.config.appFramework == .UIKit {
            // ✅ UIKit path unchanged — prod, don't touch
            if isOSProvidedViewControllerToSkip() {
                return
            }
        } else {
            // ✅ SwiftUI path: filter noisy system VCs, keep HostingControllers
            if isSwiftUISystemNoisyViewController() {
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
        if Userpilot.shared.config.appFramework == .SwiftUI,
           screenClassName.contains("HostingController") {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                Userpilot.shared.autoCaptureEngine.trackScreen(buildScreenTrackingPayload())
            }
        } else {
            Userpilot.shared.autoCaptureEngine.trackScreen(buildScreenTrackingPayload())
        }
    }

    // MARK: Payload Building

    private func buildScreenTrackingPayload() -> ScreenTrackingPayload {
        let config = Userpilot.shared.config

        if let alert = self as? UIAlertController {
            return ScreenTrackingPayload(
                currentScreen: resolvedScreenNameForCapture(),
                screenClass: screenClassName,
                screenType: screenType,
                navigationTitle: config.enableScreenTitleCapture ? resolveNavigationTitle() : nil,
                isUserpilotContainerClass: type(of: self).isUserpilotContainerClass,
                vcAccessibilityIdentifier: view.accessibilityIdentifier,
                vcAccessibilityLabel: view.accessibilityLabel,
                isDialogPresentation: true,
                alertTitle: alert.title,
                alertMessage: alert.message
            )
        }

        return ScreenTrackingPayload(
            currentScreen: resolvedScreenNameForCapture(),
            screenClass: screenClassName,
            screenType: screenType,
            navigationTitle: config.enableScreenTitleCapture ? resolveNavigationTitle() : nil,
            isUserpilotContainerClass: type(of: self).isUserpilotContainerClass,
            vcAccessibilityIdentifier: view.accessibilityIdentifier,
            vcAccessibilityLabel: view.accessibilityLabel
        )
    }
}
