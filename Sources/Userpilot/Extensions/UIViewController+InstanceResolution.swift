//
//  UIViewController+InstanceResolution.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Identifies containers that allow instance ownership lookup to continue through their parents.
//

import UIKit

internal extension UIViewController {

    /// Unclaimed hosting and navigation containers allow owner lookup to continue at their parent.
    /// Other controller types stop the walk and leave fallback selection to the resolver.
    var continuesOutwardInstanceResolution: Bool {
        let className = String(describing: type(of: self))
        if className.contains("HostingController") { return true }
        if className.contains("HostingViewController") { return true }
        if self is UINavigationController { return true }
        if self is UITabBarController { return true }
        return false
    }
}
