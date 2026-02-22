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

/// Extension providing automatic screen tracking for UIViewController
internal extension UIViewController {

    // MARK: - Swizzled Methods

    /// Swizzled viewWillAppear that captures auto screen events
    /// - Parameter animated: Whether the appearance is animated
    @objc
    func userpilot__viewWillAppear(animated: Bool) {
        captureScreenIfNeeded()
        captureAlertPresentedIfNeeded()
        // This calls the original implementation of viewWillAppear since it has been swizzled
        userpilot__viewWillAppear(animated: animated)
    }

    // MARK: - Private Methods

    // MARK: - Ignored System View Controllers

    /// System UIKit view controllers that should never be tracked.
    /// These are internal classes used by the keyboard, input accessories, etc.
    private static let ignoredScreenClassPrefixes: [String] = [
        "_UI",                      // _UICursorAccessoryViewController, etc.
        "UIInput",                  // UIInputWindowController
        "UISystemKeyboard",         // UISystemKeyboardDockController
        "UICompatibilityInput",     // UICompatibilityInputViewController
        "UIEditingOverlay",         // UIEditingOverlayViewController
        "UIKBVisual",               // UIKBVisualEffectView controllers
        "UIPrediction",             // UIPredictionViewController
        "UISystem",                 // UISystemInputAssistantViewController
        "UIRemoteKeyboard",         // UIRemoteKeyboardWindow controllers
        "UIKeyboard"                // UIKeyboardImpl controllers
    ]

    /// Captures screen event if all conditions are met
    private func captureScreenIfNeeded() {
        // 1. Check if SDK is initialized and screen autocapture is enabled
        guard Userpilot.isInitialized,
              Userpilot.shared.config.enableScreenAutocapture else { return }

        // 2. Skip internal UIKit system view controllers (keyboard, input, etc.)
        let className = screenClassName
        for prefix in Self.ignoredScreenClassPrefixes where className.hasPrefix(prefix) {
            return
        }

        // 3. Check if this VC is marked as untracked via associated object
        let untracked = objc_getAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey
        ) as? Bool ?? false
        guard !untracked else { return }

        // 4. Check if this VC has opted out via userpilotIgnoreScreen
        guard !userpilotIgnoreScreen else { return }

        // 5. Skip container classes - they don't capture, their children do
        guard !type(of: self).isUserpilotContainerClass else { return }

        // Build and send the screen tracking payload
        let payload = buildScreenTrackingPayload()
        Userpilot.shared.uiKitAutoCaptureEngine.handleScreenTracked(payload)
    }

    /// Fires a "view_presented" interaction event when a UIAlertController appears
    private func captureAlertPresentedIfNeeded() {
        guard Userpilot.isInitialized else { return }
        guard Userpilot.shared.config.enableInteractionAutocapture else { return }

        guard let alert = self as? UIAlertController else { return }

        var payload = InteractionPayload(
            interactionType: .viewPresented,
            elementType: "UIAlertController"
        )

        payload.elementText = alert.title
        payload.stringValue = alert.message

        Userpilot.shared.uiKitAutoCaptureEngine.handleInteraction(payload)
    }

    /// Builds a screen tracking payload for this view controller
    /// - Returns: The screen tracking payload
    private func buildScreenTrackingPayload() -> ScreenTrackingPayload {
        let config = Userpilot.shared.config

        return ScreenTrackingPayload(
            autoCaptureSource: FrameworkType.uiKit.rawValue,
            currentScreen: uiKitScreenNameResolver(),
            screenClass: screenClassName,
            screenType: screenType,
            previousScreen: "",  // Will be filled by UIKitAutoCaptureEngine
            previousScreenClass: "",  // Will be filled by UIKitAutoCaptureEngine
            screenPath: buildScreenPath(),
            navigationTitle: config.disableScreenTitleCapture ? nil : resolveNavigationTitle(),
            isRootScreen: isRootViewController,
            timestamp: Date().timeIntervalSince1970,
            isUserpilotContainerClass: type(of: self).isUserpilotContainerClass,
            tabName: tabBarController?.selectedViewController?.tabBarItem?.title,
            tabIndex: tabBarController?.selectedIndex
        )
    }
}
