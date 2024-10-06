//
//  UIButton+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This file contains an extension for the `UIButton` class, providing helper methods
//  for capturing button click events and communicating these events using the NotificationCenter.
//
//  Extensions include:
//  - `captureButtonClick()`: Captures button click details and posts them to `NotificationCenter`.
//  - `userpilot_sendAction(_:to:for:)`: Swizzled method that captures button click details before
//  calling the original `sendAction` implementation.
//

import Foundation
import UIKit

internal extension UIButton {

    // MARK: - Capture button details
    func captureButtonClick() {
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
