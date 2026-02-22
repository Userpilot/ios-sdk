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

// MARK: - UIViewController Customization Properties

/// Public extension for customizing screen capture logic.
/// Developers can override these properties on their view controller subclasses
/// to customize how Userpilot captures screen events.
public extension UIViewController {

    // MARK: - Container Class Customization

    /// Indicates whether this view controller class should be treated as a container
    /// for screens (similar to UINavigationController, UITabBarController, etc.).
    ///
    /// By default, Userpilot captures screens on the direct children of
    /// `UISplitViewController`, `UINavigationController`, `UITabBarController`, and `UIPageViewController`.
    /// Override this property and return `true` to designate that the direct children of your
    /// custom container should be considered screens.
    ///
    /// Example:
    /// ```swift
    /// extension SignUpFlowViewController {
    ///     open override class var isUserpilotContainerClass: Bool {
    ///         true
    ///     }
    /// }
    /// ```
    @objc
    class var isUserpilotContainerClass: Bool {
        // Default container classes
        if self is UINavigationController.Type ||
            self is UITabBarController.Type ||
            self is UISplitViewController.Type ||
            self is UIPageViewController.Type {
            return true
        }
        return false
    }

    // MARK: - Screen Name Customization

    /// The custom screen name to use for screen events.
    ///
    /// By default, the screen name captured is the class name of the ViewController.
    /// Override this property to provide a custom name for the captured screen event.
    ///
    /// Example:
    /// ```swift
    /// extension MyViewController {
    ///     open override var userpilotScreenName: String? {
    ///         "Main Signup Flow"
    ///     }
    /// }
    /// ```
    @objc
    var userpilotScreenName: String? {
        return nil
    }

    // MARK: - Screen Title Customization

    /// The custom screen title to use for screen events.
    ///
    /// Override this property to customize the title captured for screen events,
    /// or return `nil` to disable title capture for this specific view controller.
    ///
    /// Example:
    /// ```swift
    /// extension PrivateViewController {
    ///     open override var userpilotScreenTitle: String? {
    ///         nil  // Disable title capture
    ///     }
    /// }
    /// ```
    @objc
    var userpilotScreenTitle: String? {
        // Return navigation title, tabBar title, or VC title
        if let title = navigationItem.title, !title.isEmpty {
            return title
        }
        if let tabBarItem = tabBarItem, let title = tabBarItem.title, !title.isEmpty {
            return title
        }
        if let title = title, !title.isEmpty {
            return title
        }
        return nil
    }

    // MARK: - Ignore Screen Capture

    /// Whether this view controller should be ignored for screen capture.
    ///
    /// Override this property and return `true` to prevent screen events
    /// from being captured for this view controller.
    ///
    /// Example:
    /// ```swift
    /// extension SplashViewController {
    ///     open override var userpilotIgnoreScreen: Bool {
    ///         true
    ///     }
    /// }
    /// ```
    @objc
    var userpilotIgnoreScreen: Bool {
        return false
    }
}

// MARK: - UIView Extension

/// Extension providing screen name resolution functionality for UIView
internal extension UIView {
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

// MARK: - Internal UIViewController Extension

/// Extension providing screen name resolution functionality for UIViewController
internal extension UIViewController {
    /// Resolves the screen name from a view controller with priority order
    /// - Returns: The resolved screen name string
    func uiKitScreenNameResolver() -> String {
        // 1. Check for custom screen name override (highest priority)
        if let customName = userpilotScreenName, !customName.isEmpty {
            return customName
        }

        // 2. Check if screen title capture is disabled
        let config = Userpilot.isInitialized ? Userpilot.shared.config : nil
        let titleCaptureDisabled = config?.disableScreenTitleCapture ?? false

        if !titleCaptureDisabled {
            // 3. Navigation title
            if let title = navigationItem.title, !title.isEmpty {
                return title
            }

            // 4. TabBar item title
            if let tabBarTitle = extractTabBarTitle() {
                return tabBarTitle
            }

            // 5. View controller's title property
            if let title = title, !title.isEmpty {
                return title
            }
        }

        // 6. Fallback to class name
        return displayName
    }

    /// Resolves the navigation title for the view controller
    /// - Returns: The navigation title or nil if capture is disabled
    func resolveNavigationTitle() -> String? {
        let config = Userpilot.isInitialized ? Userpilot.shared.config : nil
        let titleCaptureDisabled = config?.disableScreenTitleCapture ?? false

        if titleCaptureDisabled {
            return nil
        }

        return userpilotScreenTitle
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

    /// Returns the full class name of the view controller
    var screenClassName: String {
        return String(describing: type(of: self))
    }

    /// Determines the screen type based on the view controller type
    var screenType: String {
        if self is UINavigationController {
            return "NavigationController"
        } else if self is UITabBarController {
            return "TabBarController"
        } else if self is UISplitViewController {
            return "SplitViewController"
        } else if self is UIPageViewController {
            return "PageViewController"
        } else if String(describing: type(of: self)).contains("UIHostingController") {
            return "HostingController"
        }
        return "ViewController"
    }

    /// Determines if this view controller is a root view controller
    var isRootViewController: Bool {
        // Check if it's the window's root
        if view.window?.rootViewController === self {
            return true
        }

        // Check if it's the first VC in a navigation controller
        if let navController = navigationController {
            return navController.viewControllers.first === self
        }

        // Check if it's directly presented on the window
        if parent == nil && presentingViewController == nil {
            return true
        }

        return false
    }

    /// Builds the screen path representing the navigation hierarchy
    func buildScreenPath() -> String {
        var pathComponents: [String] = []
        var currentViewController: UIViewController? = self

        while let viewController = currentViewController {
            let name = viewController.userpilotScreenName ?? viewController.displayName
            pathComponents.insert(name, at: 0)

            // Navigate up the hierarchy
            if let presenting = viewController.presentingViewController {
                currentViewController = presenting
            } else if let navController = viewController.navigationController, viewController !== navController {
                currentViewController = navController
            } else if let tabController = viewController.tabBarController, viewController !== tabController {
                currentViewController = tabController
            } else if let parent = viewController.parent, viewController !== parent {
                currentViewController = parent
            } else {
                break
            }
        }

        return pathComponents.joined(separator: "/")
    }
}
