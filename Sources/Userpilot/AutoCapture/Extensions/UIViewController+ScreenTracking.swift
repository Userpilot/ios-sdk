//
//  UIViewController+ScreenTracking.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Provides controller screen names and metadata through ScreenNameResolver,
//  and stores the custom screen name supplied by the SwiftUI bridge.
//

import UIKit

// The stable address of this private variable identifies the property's associated storage.
private var swiftUIScreenNameKey: UInt8 = 0

internal extension UIViewController {

    var userpilotSwiftUIScreenName: String? {
        get { objc_getAssociatedObject(self, &swiftUIScreenNameKey) as? String }
        set {
            objc_setAssociatedObject(
                self, &swiftUIScreenNameKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func resolvedScreenNameForCapture() -> String {
        ScreenNameResolver.resolvedName(for: self)
    }

    func buildScreenPath() -> String {
        ScreenNameResolver.buildScreenPath(for: self)
    }

    func resolveNavigationTitle() -> String? {
        // Use the owning instance's config so navigation titles are gated by the
        // tenant whose VC this is.
        guard let config = InstanceResolver.shared.target(forViewController: self)?.config,
              config.enableScreenTitleCapture
        else { return nil }
        return userpilotScreenTitle
    }

    var displayName: String {
        ScreenNameResolver.displayName(self)
    }

    func getViewControllerName() -> String? {
        ScreenNameResolver.getViewControllerName(self)
    }

    var screenClassName: String {
        String(describing: type(of: self))
    }

    var screenType: String {
        if self is UINavigationController { return "UINavigationController" }
        if self is UITabBarController { return "UITabBarController" }
        if self is UISplitViewController { return "UISplitViewController" }
        if self is UIPageViewController { return "UIPageViewController" }
        if String(describing: type(of: self)).contains("UIHostingController") {
            return "UIHostingController"
        }
        return "UIViewController"
    }

    var isRootViewController: Bool {
        if view.window?.rootViewController === self { return true }
        if let nav = navigationController, nav.viewControllers.first === self { return true }
        if parent == nil && presentingViewController == nil { return true }
        return false
    }

    func uiKitScreenNameResolver() -> String {
        resolvedScreenNameForCapture()
    }
}
