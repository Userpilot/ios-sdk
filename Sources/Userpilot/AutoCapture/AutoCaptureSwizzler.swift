//
//  AutoCaptureSwizzler.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  AutoCaptureSwizzler manages method swizzling for automatic screen and interaction tracking
//  across UIKit and SwiftUI components.
//

import UIKit

/// `AutoCaptureSwizzler` handles method swizzling operations for automatic capture functionality.
internal enum AutoCaptureSwizzler {
    // MARK: - Screen Tracking Flags

    /// Flag to track if UIKit screen tracking swizzling has been performed
    private static var didSwizzleUIKitScreens = false

    /// Flag to track if SwiftUI screen tracking swizzling has been performed
    private static var didSwizzleSwiftUIScreens = false

    /// Flag to track if tab bar tracking swizzling has been performed
    private static var didSwizzleTabBar = false

    // MARK: - Interaction Tracking Flags

    /// Flag to track if UIWindow.sendEvent swizzling has been performed
    private static var didSwizzleSendEvent = false

    /// Flag to track if UIControl.sendAction swizzling has been performed
    private static var didSwizzleControlSendAction = false

    /// Flag to track if text field notifications have been registered
    private static var didRegisterTextFieldNotifications = false

    /// Flag to track if text view notifications have been registered
    private static var didRegisterTextViewNotifications = false

    // MARK: - Screen Tracking Methods

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

    // MARK: - Interaction Tracking Methods

    /// Swizzles UIWindow.sendEvent to enable automatic touch/click tracking
    /// This captures: regular view taps, table view cell taps, collection view cell taps
    static func swizzleClickTracking() {
        guard !didSwizzleSendEvent else { return }
        didSwizzleSendEvent = true
        UIWindow.swizzleSendEvent()
    }

    /// Swizzles UIControl.sendAction to enable automatic control interaction tracking
    /// This captures: button taps, switch changes, slider changes, etc. with action names
    static func swizzleControlTracking() {
        guard !didSwizzleControlSendAction else { return }
        didSwizzleControlSendAction = true
        Swizzler.swapInstanceMethods(
            on: UIControl.self,
            original: #selector(UIControl.sendAction(_:to:for:)),
            swizzled: #selector(UIControl.userpilot__sendAction(_:to:for:))
        )
    }

    /// Registers notification for UITextField text changes (cached, flushed on screen change)
    static func registerTextFieldNotifications() {
        guard !didRegisterTextFieldNotifications else { return }
        didRegisterTextFieldNotifications = true

        NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let textField = notification.object as? UITextField else { return }
            textField.cacheTextFieldChanged()
        }
    }

    /// Registers notification for UITextView text changes (cached, flushed on screen change)
    static func registerTextViewNotifications() {
        guard !didRegisterTextViewNotifications else { return }
        didRegisterTextViewNotifications = true

        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let textView = notification.object as? UITextView else { return }
            textView.cacheTextViewChanged()
        }
    }

    // MARK: - Setup All Interaction Tracking

    /// Sets up all interaction tracking swizzles and notifications
    static func setupAllInteractionTracking() {
        // UIWindow.sendEvent captures: regular views, table cells, collection cells
        swizzleClickTracking()
        // UIControl.sendAction captures: buttons, switches, sliders, etc. with action names
        swizzleControlTracking()
        // Text input notifications
        registerTextFieldNotifications()
        registerTextViewNotifications()
    }
}
