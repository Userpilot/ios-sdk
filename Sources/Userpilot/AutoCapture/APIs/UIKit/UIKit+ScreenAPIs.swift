//
//  UIKit+Screen.swift
//  Userpilot
//
//  Created by Motasem Hamed on 29/03/2026.
//

import UIKit

// MARK: - Public API

/// Public extension for customizing screen capture logic.
/// Developers can override these properties on their view controller subclasses
/// to customize how Userpilot captures screen events.
extension UIViewController {

    /// Indicates whether this view controller class should be treated as a container
    /// for screens (similar to UINavigationController, UITabBarController, etc.).
    @objc
    open class var isUserpilotContainerClass: Bool {
        if self is UINavigationController.Type || self is UITabBarController.Type
            || self is UISplitViewController.Type || self is UIPageViewController.Type {
            return true
        }
        return false
    }

    /// The custom screen name to use for screen events. Override to provide a custom name.
    @objc
    open var userpilotScreenName: String? {
        return nil
    }

    /// The custom screen title to use for screen events. Override or return nil to disable.
    @objc
    open var userpilotScreenTitle: String? {
        if let title = navigationItem.title, !title.isEmpty { return title }
        if let tabBarItem = tabBarItem, let title = tabBarItem.title, !title.isEmpty {
            return title
        }
        if let title = title, !title.isEmpty { return title }
        return nil
    }

    /// Whether this view controller should be ignored for screen capture.
    @objc
    open var userpilotIgnoreScreen: Bool {
        return false
    }
}
