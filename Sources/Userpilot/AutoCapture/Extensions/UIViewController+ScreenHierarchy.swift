//
//  UIViewController+ScreenHierarchy.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Captures bounded navigation and container snapshots at screen appearance.
//

import UIKit

internal extension UIViewController {
    /// Reads containment on main, crossing a modal's presentation edge only after its own parents.
    /// Earlier navigation-stack entries are siblings, so they never become ancestors here.
    func captureScreenContainerHierarchy() -> [String]? {
        var classes: [String] = []
        var visited = Set<ObjectIdentifier>()
        var current: UIViewController? = self
        while let controller = current {
            // A malformed custom container must not loop or report a partial path as complete.
            guard classes.count < 64, visited.insert(ObjectIdentifier(controller)).inserted else { return nil }
            classes.append(controller.screenClassName)
            current = controller.parent ?? controller.presentingViewController
        }
        return classes.reversed()
    }

    /// Reads the active UIKit stack once on main; SwiftUI routes are not exposed by this API.
    func captureScreenHierarchy() -> [String]? {
        guard let navigation = navigationController, navigation.topViewController === self else { return nil }
        let controllers = navigation.viewControllers
        guard !controllers.isEmpty, controllers.count <= 64,
              !controllers.contains(where: { $0.screenClassName.contains("HostingController") }) else { return nil }
        return controllers.map(\.screenClassName)
    }

}
