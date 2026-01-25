//
//  UIKitScreenNameResolver.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIKitScreenNameResolver provides utilities for resolving screen names from UIKit
//  view controllers and views, prioritizing meaningful titles over class names.
//

import UIKit

/// Extension providing screen name resolution functionality for UIView
extension UIView {
    /// Resolves the screen name from a view with meaningful title priority
    /// - Returns: The resolved screen name string
    func userpilotResolvedScreenName() -> String {
        guard let viewController = closestViewController() else {
            return "UnknownScreen"
        }

        return viewController.uiKitScreenNameResolver()
    }

    /// Finds the closest UIViewController in the responder chain
    /// - Returns: The closest view controller or nil
    func closestViewController() -> UIViewController? {
        var nextResponder = self.next
        while nextResponder != nil {
            if let viewController = nextResponder as? UIViewController { return viewController }
            nextResponder = nextResponder?.next
        }
        return nil
    }
}

/// Extension providing screen name resolution functionality for UIViewController
extension UIViewController {
    /// Resolves the screen name from a view controller with priority order
    /// - Returns: The resolved screen name string
    func uiKitScreenNameResolver() -> String {
        // 1. Navigation title (highest priority)
        if let title = navigationItem.title, !title.isEmpty {
            return title
        }

        // 2. TabBar item title
        if let tabBarTitle = extractTabBarTitle() {
            return tabBarTitle
        }

        // 3. View controller's title property
        if let title = title, !title.isEmpty {
            return title
        }

        // 4. Fallback to class name
        return displayName
    }

    /// Extracts the TabBar item title from the view controller
    /// - Returns: The tab bar title or nil
    private func extractTabBarTitle() -> String? {
        if let tabBarItem = tabBarItem,
           let title = tabBarItem.title,
           !title.isEmpty {
            return title
        }

        if let tabBarController = tabBarController {
            if let selectedVC = tabBarController.selectedViewController {
                if isViewController(containedIn: selectedVC) {
                    if let title = selectedVC.tabBarItem?.title, !title.isEmpty {
                        return title
                    }
                }
            }

            if let viewControllers = tabBarController.viewControllers {
                return viewControllers
                    .first { isViewController(containedIn: $0) }
                    .flatMap { viewController in
                        let title = viewController.tabBarItem?.title
                        return title?.isEmpty == false ? title : nil
                    }
            }
        }

        return nil
    }

    /// Checks if a view controller is contained within another
    /// - Parameter container: The container view controller to check
    /// - Returns: True if contained, false otherwise
    private func isViewController(containedIn container: UIViewController) -> Bool {
        if self === container {
            return true
        }

        if let navController = container as? UINavigationController {
            return navController.viewControllers.contains(where: { $0 === self })
        }

        if container.children.contains(where: { $0 === self }) {
            return true
        }

        for child in container.children where isViewController(containedIn: child) {
            return true
        }

        return false
    }

    /// Gets a display-friendly name for the view controller
    var displayName: String {
        var name = getViewControllerName()
            ?? String(describing: self.classForCoder)
        if name.starts(with: "UIHostingController<") {
            name = "UIHostingController"
        }
        return name
    }

    /// Gets a cleaned view controller name without "ViewController" suffix
    /// - Returns: The cleaned view controller name or nil
    func getViewControllerName() -> String? {
        var title: String? = String(describing: self.classForCoder)
            .replacingOccurrences(of: "ViewController", with: "")

        if title?.isEmpty == true {
            title = self.title ?? nil
        }

        return title
    }
}
