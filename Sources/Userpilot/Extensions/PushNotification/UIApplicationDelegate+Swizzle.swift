//
//  UIApplicationDelegate+Swizzle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  This extension of `UIApplication` handles method swizzling for
//  `didRegisterForRemoteNotificationsWithDeviceToken`. It allows the SDK to intercept
//  push token registration events and forward them to Userpilot, even if the app delegate
//  doesn't explicitly implement the corresponding method.
//

import UIKit

internal extension UIApplication {
    /// Hooks the host's actual delegate class, including apps that omit the optional APNs callback.
    /// `Swizzler` keeps repeated SDK-instance setup from exchanging the same callback twice.
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
        // A host without this optional callback still needs a valid forwarding target after exchange.
    }

    @objc
    func userpilot__applicationDidRegisterForRemoteNotificationsWithDeviceToken(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationAutoConfig.didRegister(deviceToken: deviceToken)

        // After exchange this selector points to the host's implementation (or the placeholder).
        // It looks recursive, but preserves the host's APNs token callback after SDK delivery.
        userpilot__applicationDidRegisterForRemoteNotificationsWithDeviceToken(
            application,
            didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
        )
    }
}
