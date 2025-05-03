//
//  UIApplication+PushSwizzling.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 17/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  This extension of `UIApplication` handles method swizzling for
//  `didRegisterForRemoteNotificationsWithDeviceToken`. It allows the SDK to intercept
//  push token registration events and forward them to Userpilot, even if the app delegate
//  doesn't explicitly implement the corresponding method.
//

import UIKit

extension UIApplication {
    static func swizzleDidRegisterForDeviceToken() {
        guard let appDelegateInstance = UIApplication.shared.delegate else { return }

        Swizzler.swizzle(
            targetInstance: appDelegateInstance,
            targetSelector: NSSelectorFromString("application:didRegisterForRemoteNotificationsWithDeviceToken:"),
            replacementOwner: UIApplication.self,
            placeholderSelector:
                #selector(userpilot__placeholderApplicationDidRegisterForRemoteNotificationsWithDeviceToken),
            swizzleSelector:
                #selector(userpilot__applicationDidRegisterForRemoteNotificationsWithDeviceToken)
        )
    }

    @objc
    func userpilot__placeholderApplicationDidRegisterForRemoteNotificationsWithDeviceToken(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // this gives swizzling something to replace, if the existing delegate doesn't already
        // implement this function.
    }

    @objc
    func userpilot__applicationDidRegisterForRemoteNotificationsWithDeviceToken(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationAutoConfig.didRegister(deviceToken: deviceToken)

        // Also call the original implementation
        userpilot__applicationDidRegisterForRemoteNotificationsWithDeviceToken(
            application,
            didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
        )
    }
}
