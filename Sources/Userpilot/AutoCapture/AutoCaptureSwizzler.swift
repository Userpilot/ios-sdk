//
//  AutoCaptureSwizzler.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  AutoCaptureSwizzler manages method swizzling for automatic screen and click tracking
//  across UIKit and SwiftUI components.
//

import UIKit

/// `AutoCaptureSwizzler` handles method swizzling operations for automatic capture functionality.
internal enum AutoCaptureSwizzler {
    // MARK: - Properties

    /// Flag to track if UIKit screen tracking swizzling has been performed
    private static var didSwizzleUIKitScreens = false

    /// Flag to track if SwiftUI screen tracking swizzling has been performed
    private static var didSwizzleSwiftUIScreens = false

    /// Flag to track if tab bar tracking swizzling has been performed
    private static var didSwizzleTabBar = false

    /// Flag to track if click event swizzling has been performed
    private static var didSwizzleSendEvent = false

    // MARK: - Static Methods

    /// Swizzles UIViewController.viewWillAppear to enable UIKit screen tracking
    static func swizzleUIKitScreenTracking() {
        guard !didSwizzleUIKitScreens else { return }
        didSwizzleUIKitScreens = true
        Swizzler.swapInstanceMethods(
            on: UIViewController.self,
            original: #selector(UIViewController.viewWillAppear(_:)),
            swizzled: #selector(UIViewController.userpilot__viewWillAppear)
        )
    }

    /// Swizzles methods for SwiftUI screen tracking support
    static func swizzleSwiftUIScreenTracking() {
        guard !didSwizzleSwiftUIScreens else { return }
        didSwizzleSwiftUIScreens = true
        swizzleUIKitScreenTracking()
    }

    /// Swizzles UITabBarController properties to enable tab selection tracking
    static func swizzleTabBarTracking() {
        guard !didSwizzleTabBar else { return }
        didSwizzleTabBar = true
        Swizzler.swapInstanceMethods(
            on: UITabBarController.self,
            original: #selector(setter: UITabBarController.selectedIndex),
            swizzled: #selector(UITabBarController.userpilot__setSelectedIndex(_:))
        )
        Swizzler.swapInstanceMethods(
            on: UITabBarController.self,
            original: #selector(setter: UITabBarController.selectedViewController),
            swizzled: #selector(UITabBarController.userpilot__setSelectedViewController(_:))
        )
    }

    /// Swizzles UIWindow.sendEvent to enable automatic click tracking
    static func swizzleClickTracking() {
        guard !didSwizzleSendEvent else { return }
        didSwizzleSendEvent = true
        UIWindow.swizzleSendEvent()
    }
}
