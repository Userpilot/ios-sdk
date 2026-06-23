//
//  UITabBarController+Extensions.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UITabBarController+Extensions provides automatic tab selection tracking
//  through method swizzling for analytics capture.
//

import UIKit

/// Extension providing automatic tab selection tracking for UITabBarController
extension UITabBarController {
    // MARK: - Swizzled Methods

    /// Swizzled setter for selectedIndex that tracks tab changes
    /// - Parameter index: The selected tab index
    @objc dynamic func userpilot__setSelectedIndex(_ index: Int) {
        self.userpilot__setSelectedIndex(index)
        trackTabSwitch(in: self)
    }

    /// Swizzled setter for selectedViewController that tracks tab changes
    /// - Parameter viewController: The selected view controller
    @objc dynamic func userpilot__setSelectedViewController(_ viewController: UIViewController?) {
        self.userpilot__setSelectedViewController(viewController)
        trackTabSwitch(in: self)
    }

    /// Tracks tab switch events by routing to the owning Userpilot instance.
    /// - Parameter tabBarController: The tab bar controller that changed tabs
    func trackTabSwitch(in tabBarController: UITabBarController) {
        guard Userpilot.isInitialized else { return }
        guard let selectedVC = tabBarController.selectedViewController else { return }

        let tabIndex = tabBarController.selectedIndex
        let tabTitle = selectedVC.tabBarItem?.title
            ?? "\(AutoCaptureConstants.defaultTabTitlePrefix)\(tabIndex + 1)"

        // Resolve via the *selected* view controller, not the container, so the
        // event attributes to the tenant whose screen the user just navigated to.
        InstanceResolver.shared.handleTabSelected(
            name: tabTitle,
            index: tabIndex,
            source: selectedVC
        )
    }
}
