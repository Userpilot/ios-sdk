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
    private static func isAppleSystemFrameworkBundle(_ bundle: Bundle) -> Bool {
        guard let id = bundle.bundleIdentifier?.lowercased() else { return false }
        return id.hasPrefix("com.apple.")
    }

    /// Skip screen capture for classes implemented in Apple OS frameworks (UIKit, SwiftUI, SpringBoard, …).
    /// Exception: `UIAlertController` (`dialog_presented`).
    private static func isOSProvidedViewControllerToSkip(_ viewController: UIViewController) -> Bool {
        if viewController is UIAlertController { return false }
        return isAppleSystemFrameworkBundle(Bundle(for: type(of: viewController)))
    }

    /// Built-in UIKit container types (also skips app subclasses, e.g. `class MyNav: UINavigationController`).
    private static func isUIKitSystemContainerViewController(_ viewController: UIViewController) -> Bool {
        viewController is UINavigationController
            || viewController is UITabBarController
            || viewController is UISplitViewController
            || viewController is UIPageViewController
    }

    // MARK: Private

    private func captureScreenIfNeeded() {
        guard Userpilot.isInitialized,
              Userpilot.shared.config.enableScreenAutoCapture
        else { return }

        // guard !type(of: self).isUserpilotContainerClass else { return }
        guard !Self.isUIKitSystemContainerViewController(self) else { return }

        if Userpilot.shared.config.appFramework == .UIKit {
            if Self.isOSProvidedViewControllerToSkip(self) {
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
                let payload = self.buildScreenTrackingPayload()
                Userpilot.shared.autoCaptureEngine.trackScreen(payload)
            }
        } else {
            let payload = buildScreenTrackingPayload()
            Userpilot.shared.autoCaptureEngine.trackScreen(payload)
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
