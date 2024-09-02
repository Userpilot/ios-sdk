//
//  UIButton+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// UIButton+Data contains extensions helper methods
//

import Foundation
import UIKit

extension UIButton {

    // MARK: - Capture button details
    internal func captureButtonClick() {
        let buttonName = self.titleLabel?.text ??
        self.accessibilityIdentifier ??
        "Target: \(String(describing: target))"

        // communicate the tracked screen back to UIButton Tracker
        NotificationCenter.userpilot.post(
            name: .userpilotTrackedButton,
            object: self,
            userInfo: Notification.toInfo(buttonName)
        )
    }

    // MARK: - New swizzle method
    @objc
    func userpilot_sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        captureButtonClick()

        // this is calling the original implementation of sendAction since it has been swizzled
        userpilot_sendAction(action, to: target, for: event)  // This now calls the original sendAction
    }

}
