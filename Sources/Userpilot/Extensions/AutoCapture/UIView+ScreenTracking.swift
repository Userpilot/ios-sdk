//
//  UIView+ScreenTracking.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves a view’s owning controller for screen capture and stores custom
//  screen-name tags supplied by the SwiftUI bridge.
//

import UIKit

// The stable address of this private variable identifies the property's associated storage.
private var userpilotScreenNameTagKey: UInt8 = 0

internal extension UIView {

    func userpilotResolvedScreenName() -> String {
        guard let viewController = closestViewController() else {
            return Constants.AutoCapture.unknownScreenHierarchyPlaceholder
        }
        return viewController.screenClassName
    }

    func closestViewController() -> UIViewController? {
        var nextResponder = self.next
        while let responder = nextResponder {
            if let viewController = responder as? UIViewController { return viewController }
            nextResponder = responder.next
        }
        return nil
    }

    var userpilotScreenNameTag: String? {
        get { objc_getAssociatedObject(self, &userpilotScreenNameTagKey) as? String }
        set {
            objc_setAssociatedObject(
                self, &userpilotScreenNameTagKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
