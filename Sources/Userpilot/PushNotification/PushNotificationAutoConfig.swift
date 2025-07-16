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
    // A PushNotificationMonitoring to process push notifications actions
    private static weak var pushNotificationMonitor: PushNotificationMonitoring?
    // In some case like in plugins(ReactNative and FLutter), didReceive called
    // while pushNotificationMonitor is not set.
    private static var response: UNNotificationResponse?

    /// Registers a `PushNotificationMonitoring` observer to handle push notifications.
    ///
    /// - Parameter observer: The `PushNotificationMonitoring` instance that will handle push notifications.
    static func register(observer: PushNotificationMonitoring) {
        pushNotificationMonitor = observer
        // in case we have a pending notification, process it
        if let response {
            _ = observer.didReceiveNotification(
                response: response,
                completionHandler: {})
            self.response = nil
        }
    }

    /// Configures the app to automatically handle push notifications by swizzling necessary methods.
    /// This method registers the app for remote notifications and modifies the notification center delegate.
    static func configureAutomatically() {
        UIApplication.swizzleDidRegisterForDeviceToken()
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.swizzleNotificationCenterGetDelegate()
    }

    /// Called when the device successfully registers for push notifications and receives the device token.
    /// This method passes the device token to the registered `PushNotificationMonitoring` observer.
    ///
    /// - Parameter deviceToken: The device token received from APNs (Apple Push Notification Service).
    static func didRegister(deviceToken: Data) {
        // Pass device token to all observing PushNotificationMonitor instances
        if let pushNotificationMonitor {
            pushNotificationMonitor.setPushToken(deviceToken)
        }
    }

    /// Called when a push notification is received and handled by the app.
    /// If the first `PushNotificationMonitoring` observer handles the response,
    /// the `completionHandler` will be executed.
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
        // Stop at the first PushNotificationMonitor that successfully handles the notification
        if let pushNotificationMonitor {
            // `completionHandler` is executed if this returns true
            didHandleResponse = pushNotificationMonitor.didReceiveNotification(
                response: response,
                completionHandler: completionHandler
            )
        } else {
            // cache response to handle it when we have active pushNotificationMonitor
            self.response = response
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
