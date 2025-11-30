//
//  UIApplication+TopViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 2025-10-16.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Utilities to get the top view controller and open URLs.
//

import UIKit

internal protocol TopControllerGetting {
    var hasActiveWindowScenes: Bool { get }

    func topViewController() -> UIViewController?
}

internal protocol URLOpening {
    func open(_ url: URL)
}

extension UIApplication: TopControllerGetting {

    @available(iOS 13.0, *)
    private var activeWindowScenes: [UIWindowScene] {
        self.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
    }

    // Prefer the active window scene, but in the case where there's no active scene, use
    // the one from the main app window.
    @available(iOS 13.0, *)
    var mainWindowScene: UIWindowScene? {
        activeWindowScenes.first
    }

    // We expose this property because a unit test cannot init a UIWindowScene for mocking different states.
    var hasActiveWindowScenes: Bool {
        if #available(iOS 13.0, *) {
            return !activeWindowScenes.isEmpty
        } else {
            return false
        }
    }

    // Note: multitasking with two instances of the same app side by side will have both
    // designated as `.foregroundActive`, and as a result the returned window may not be the one expected.
    private var activeKeyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return self.activeWindowScenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return keyWindow
        }
    }

    func topViewController() -> UIViewController? {
        let window: UIWindow? = activeKeyWindow
        guard let rootViewController = window?.rootViewController else { return nil }
        let topVC = topViewController(controller: rootViewController)

        // Return nil if a UIAlertController is currently being presented
        // Cause showing Userpilot experience could lead to pushing the UIAlert view out
        // of screen bounds!
        if topVC is UIAlertController {
            return nil
        }

        return topVC
    }

    private func topViewController(controller: UIViewController) -> UIViewController {
        if let navigationController = controller as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            if !visibleViewController.isBeingDismissed {
                return topViewController(controller: visibleViewController)
            } else if let topStack = navigationController.viewControllers.last {
                // This gets the VC under what is being dismissed
                return topViewController(controller: topStack)
            } else {
                return topViewController(controller: visibleViewController)
            }
        }
        if let tabController = controller as? UITabBarController,
           let selected = tabController.selectedViewController {
            return topViewController(controller: selected)
        }
        if let presented = controller.presentedViewController, !presented.isBeingDismissed {
            return topViewController(controller: presented)
        }
        return controller
    }
}

extension UIApplication: URLOpening {

    func open(_ url: URL) {
        open(url, options: [:])
    }

}
