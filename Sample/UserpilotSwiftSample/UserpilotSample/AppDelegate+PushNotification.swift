//
//  AppDelegate+PushNotification.swift
//  UserpilotSample
//
//  A sample code to show how to manually Configuring Push Notifications.
//

// Disabled in favor of automatic configuration

/*
import Foundation
import UserNotifications
import UIKit

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Call from `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)`
    func setupPush(application: UIApplication) {
        requestPushNotificationPermission()
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Push Notification Permission Request
    private func requestPushNotificationPermission() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        // Check if the app has already been authorized
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus == .authorized {
                // App is already authorized for push notifications
                // Register for remote notifications again to get the device token
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                // If not authorized, request permission
                UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    } else {
                        if let errorDescription = error?.localizedDescription {
                            print("Permission denied or failed to request: \(errorDescription)")
                        } else {
                            print("Permission denied or failed to request: Unknown error")
                        }
                    }
                }
            }
        }
    }

    // 2: Pass device token to Userpilot
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UserpilotManager.shared.setPushToken(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        print("Permission denied or failed to request: \(String(describing: error.localizedDescription))")
    }

    // 3: Pass the user's response to a delivered notification to Userpilot
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if UserpilotManager.shared.didReceiveNotification(response: response, completionHandler: completionHandler) {
            return
        }
        completionHandler()
    }

    // 4: Configure handling for notifications that arrive while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list])
        } else {
            completionHandler(.alert)
        }
    }
}
*/
