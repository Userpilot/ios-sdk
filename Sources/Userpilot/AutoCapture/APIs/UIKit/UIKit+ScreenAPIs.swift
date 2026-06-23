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

    /// Override to `true` on a **custom** container so child view controllers are treated as screens
    /// (same idea as `UINavigationController` / `UITabBarController`). Built-in UIKit containers are
    /// detected inside the SDK; the default is `false` for normal view controllers.
    @objc
    open class var isUserpilotContainerClass: Bool {
        false
    }

    /// The custom screen name to use for screen events. Override to provide a custom name.
    @objc
    open var userpilotScreenName: String? {
        return nil
    }

    /// The custom screen title to use for screen events. Override or return nil to disable.
    @objc
    open var userpilotScreenTitle: String? {
        // Use the owning instance's `enableScreenTitleCapture` so embedded SDKs and
        // the host app each control their own screens' title capture independently.
        let titleCaptureEnabled =
            InstanceResolver.shared.target(forViewController: self)?.config.enableScreenTitleCapture ?? true
        if let containerTitle = ScreenNameResolver.tabBarControllerPreferredTitle(
            self, titleCaptureEnabled: titleCaptureEnabled
        ) {
            return containerTitle
        }
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
