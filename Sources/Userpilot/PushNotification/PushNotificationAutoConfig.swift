//
//  PushNotificationAutoConfig.swift
//  Userpilot
//
//  Created by Motasem Hamed on 18/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  PushNotificationAutoConfig handles the automatic configuration and setup of push
//  notifications for the Userpilot SDK.
//  It manages the registration for remote notifications, the handling of push token, and delegates
//  the notification responses to the appropriate observers.
//

import UIKit

internal enum PushNotificationAutoConfig {
    // A PushMonitoring to process push notifications actions
    private static weak var pushMonitor: PushMonitoring?

    /// Registers a `PushMonitoring` observer to handle push notifications.
    ///
    /// - Parameter observer: The `PushMonitoring` instance that will handle push notifications.
    static func register(observer: PushMonitoring) {
        pushMonitor = observer
    }

    /// Configures the app to automatically handle push notifications by swizzling necessary methods.
    /// This method registers the app for remote notifications and modifies the notification center delegate.
    static func configureAutomatically() {
        UIApplication.swizzleDidRegisterForDeviceToken()
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.swizzleNotificationCenterGetDelegate()
    }

    /// Called when the device successfully registers for push notifications and receives the device token.
    /// This method passes the device token to the registered `PushMonitoring` observer.
    ///
    /// - Parameter deviceToken: The device token received from APNs (Apple Push Notification Service).
    static func didRegister(deviceToken: Data) {
        // Pass device token to all observing PushMonitor instances
        if let pushMonitor {
            pushMonitor.setPushToken(deviceToken)
        }
    }

    /// Called when a push notification is received and handled by the app.
    /// If the first `PushMonitoring` observer handles the response, the `completionHandler` will be executed.
    /// Otherwise, the `completionHandler` is executed without any special handling.
    ///
    /// - Parameters:
    ///   - response: The response to the notification containing the user's interaction with the notification.
    ///   - completionHandler: A closure to be executed when the notification has been handled.
    static func didReceive(
        _ response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        var didHandleResponse = false
        // Stop at the first PushMonitor that successfully handles the notification
        if let pushMonitor {
            // `completionHandler` is executed if this returns true
            didHandleResponse = pushMonitor.didReceiveNotification(
                response: response,
                completionHandler: completionHandler)
        }

        if !didHandleResponse {
            completionHandler()
        }
    }

    /// Called when a push notification is about to be presented to the user.
    /// This method configures the presentation options for Userpilot notifications.
    ///
    /// - Parameters:
    ///   - parsedNotification: The parsed notification to be displayed.
    ///   - completionHandler: A closure to be executed with the chosen presentation options.
    static func willPresent(
        _ parsedNotification: UserpilotNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Behavior for all Userpilot notification
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list])
        } else {
            completionHandler(.alert)
        }
    }
}
