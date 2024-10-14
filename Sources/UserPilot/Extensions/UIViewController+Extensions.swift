//
//  UIViewController+Extension.swift
//
//
//  Created by Motasem Hamed on 20/08/2024.
//
//  [Brief Description]
//  UIViewController+Extension file contains an extension for the `UIViewController` class,
// providing helper methods for obtaining class names, capturing screen events, and swizzling
// the `viewDidAppear` method to include custom tracking logic.
//

import Foundation
import UIKit

internal extension UIViewController {

    var upClassName: String {
        return String(describing: type(of: self))
    }

    var displayName: String {
        var name = String(describing: self.classForCoder)
        if name != "ViewController" {
            name = name.replacingOccurrences(of: "ViewController", with: "")
        }
        if name.starts(with: "UIHostingController<") {
            name = "UIHostingController"
        }
        return name
    }

    func captureScreen() {
        guard UIApplication.shared.topViewController() != nil else { return }

        // communicate the tracked screen back to AnalyticsTracker
        NotificationCenter.userpilot.post(name: .userpilotTrackedScreen,
                                          object: self,
                                          userInfo: Notification.toInfo(self.displayName)
        )
    }

    @objc
    func userpilot__viewDidAppear(animated: Bool) {
        captureScreen()

        // this is calling the original implementation of viewDidAppear since it has been swizzled
        userpilot__viewDidAppear(animated: animated)
    }
}
