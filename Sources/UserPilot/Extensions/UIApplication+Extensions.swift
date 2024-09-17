//
//  File.swift
//
//
//  Created by Motasem Hamed on 20/08/2024.
//
//  [Brief Description]
//  This file contains an extension of the `UIApplication` class, providing helper methods
//  for retrieving the top-most view controller and managing active window scenes.
//
//  Extensions include:
//  - `activeWindowScenes`: A computed property that returns the list of active window scenes.
//  - `hasActiveWindowScenes`: A computed property that checks if there are any active window scenes.
//  - `activeKeyWindow`: A private computed property that returns the current key window in the active window scenes.
//  - `topViewController()`: A method that returns the top-most view controller in the current window or scene.
//  - `topViewController(controller:)`: A private method that recursively finds the top-most view controller
//  from a given controller.
//

import Foundation
import UIKit

extension UIApplication {

    @available(iOS 13.0, *)
    var activeWindowScenes: [UIWindowScene] {
        self.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
    }

    // We expose this property because a unit test cannot init a UIWindowScene for mocking different states.
    var hasActiveWindowScenes: Bool {
        if #available(iOS 13.0, *) {
            return !activeWindowScenes.isEmpty
        } else {
            return false
        }
    }

    // Note: multitasking with two instances of the same app side by side
    // will have both designated as `.foregroundActive`, and as a result
    // the returned window may not be the one expected.
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
        var window: UIWindow? = activeKeyWindow

        if window == nil {
            if #available(iOS 15.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    window = windowScene.windows.first
                }
            } else {
                window = UIApplication.shared.windows.first
            }
        }

        guard let rootViewController = window?.rootViewController else { return nil }
        return topViewController(controller: rootViewController)
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
