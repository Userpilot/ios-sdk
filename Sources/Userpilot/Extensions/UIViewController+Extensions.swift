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
        // Call original first (swizzled, so this invokes the real viewWillAppear)
        userpilot__viewWillAppear(animated: animated)
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        captureScreenIfNeeded()
    }

    // MARK: Screen Capture

    /// View controller types that are not "screens" (alerts, share sheets, etc.) — skip screen capture.
    private static let nonScreenViewControllerClassNames: Set<String> = [
        "UIActivityViewController",
        "UIDocumentMenuViewController",
        "UIDocumentPickerViewController",
        "UISearchController",
        "UITrackingElementWindowController"
    ]

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

    // MARK: Private

    /// Captures screen event if all conditions are met
    private func captureScreenIfNeeded() {
        // 1. Check if SDK is initialized and screen autocapture is enabled
        guard Userpilot.isInitialized,
              Userpilot.shared.config.enableScreenAutoCapture else { return }

        // 2. Skip view controllers that are not screens (alerts, share sheets, etc.)
        let className = screenClassName
        if Self.nonScreenViewControllerClassNames.contains(className) {
            return
        }

        // 3. Skip internal UIKit system view controllers (keyboard, input, etc.)
        for prefix in Self.ignoredScreenClassPrefixes where className.hasPrefix(prefix) {
            return
        }

        // 4. Check if this VC is marked as untracked via associated object
        let untracked = objc_getAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey
        ) as? Bool ?? false
        guard !untracked else { return }

        // 5. Check if this VC has opted out via userpilotIgnoreScreen
        guard !userpilotIgnoreScreen else { return }

//        // 6. Skip container classes - they don't capture, their children do
//        guard !type(of: self).isUserpilotContainerClass else { return }

        // Build and send the screen tracking payload
        let payload = buildScreenTrackingPayload()
        Userpilot.shared.autoCaptureEngine.trackScreen(payload)
    }

    // MARK: Payload Building

    /// Builds a screen tracking payload for this view controller
    /// - Returns: The screen tracking payload
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
