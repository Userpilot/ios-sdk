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
    // MARK: - Private Types

    /// Settings for automatic screen capture modes
    private struct AutoCaptureScreenSettings {
        /// Whether UIKit screen tracking is enabled
        var uiKitEnabled: Bool = false

        /// Whether SwiftUI screen tracking is enabled
        var swiftUIEnabled: Bool = false
    }

    /// Shared settings for auto capture screen tracking
    private static var userpilotScreenSettings = AutoCaptureScreenSettings()

    // MARK: - Static Methods

    /// Updates auto capture screen settings
    /// - Parameters:
    ///   - uiKitEnabled: Whether UIKit screen tracking is enabled
    ///   - swiftUIEnabled: Whether SwiftUI screen tracking is enabled
    static func updateAutoCaptureScreens(
        uiKitEnabled: Bool? = nil,
        swiftUIEnabled: Bool? = nil
    ) {
        if let uiKitEnabled = uiKitEnabled {
            userpilotScreenSettings.uiKitEnabled = uiKitEnabled
        }
        if let swiftUIEnabled = swiftUIEnabled {
            userpilotScreenSettings.swiftUIEnabled = swiftUIEnabled
        }
    }

    // MARK: - Swizzled Methods

    /// Swizzled viewWillAppear that captures auto screen events
    /// - Parameter animated: Whether the appearance is animated
    @objc
    func userpilot__viewWillAppear(animated: Bool) {
        captureAutoScreenIfNeeded()
        // this is calling the original implementation of viewDidAppear since it has been swizzled
        userpilot__viewWillAppear(animated: animated)
    }

    // MARK: - Private Methods

    /// Captures auto screen if tracking is enabled
    private func captureAutoScreenIfNeeded() {
        if UIViewController.userpilotScreenSettings.swiftUIEnabled {
            captureAutoScreen(usingSwiftUIResolver: true)
        } else if UIViewController.userpilotScreenSettings.uiKitEnabled {
            captureAutoScreen(usingSwiftUIResolver: false)
        }
    }

    /// Captures auto screen event with appropriate resolver
    /// - Parameter usingSwiftUIResolver: Whether to use SwiftUI resolver
    private func captureAutoScreen(usingSwiftUIResolver: Bool) {
        let untracked: Bool
        if usingSwiftUIResolver {
            untracked = objc_getAssociatedObject(
                self,
                &ScreenNameTracker.untrackedScreenKey
            ) as? Bool ?? false
        } else {
            untracked = objc_getAssociatedObject(
                self,
                &ScreenNameTracker.untrackedScreenKey
            ) as? Bool ?? false
        }
        guard !untracked else { return }

        let screenName = usingSwiftUIResolver
            ? swiftUIScreenNameResolver()
            : uiKitScreenNameResolver()

        NotificationCenter.userpilot.post(
            name: .userpilotTrackedScreen,
            object: self,
            userInfo: Notification.toInfo(screenName)
        )
    }

}
