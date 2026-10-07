//
//  PushNotificationAutoConfig.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  PushNotificationAutoConfig handles the automatic configuration and setup of push
//  notifications for the Userpilot SDK.
//  It manages the registration for remote notifications, the handling of push token, and delegates
//  the notification responses to the appropriate observers.
//

import UIKit

/// Process-wide APNs hooks and weak monitor registration. Instance routing stays in each monitor.
internal enum PushNotificationAutoConfig {
    // Monitor callbacks run outside this lock: handling a response may initialize another SDK instance.
    private static let lock = NSLock()
    /// Instances own their monitors. Weak storage allows instance teardown, while registering the
    /// same monitor again does not add another recipient for APNs token callbacks.
    private static let pushNotificationMonitors = NSHashTable<AnyObject>.weakObjects()

    /// Hybrid runtimes may initialize the SDK after a notification tap reaches the native delegate.
    /// Keep the unclaimed tap until its monitor registers; looking up only existing instances here
    /// would lose cold-start taps in Flutter, React Native and Capacitor hosts.
    private static var pendingResponse: UNNotificationResponse?

    /// Adds a weak, identity-deduplicated observer and offers it the unclaimed cold-start response.
    static func register(observer: PushNotificationMonitoring) {
        let response = lock.withLock {
            pushNotificationMonitors.add(observer as AnyObject)
            return pendingResponse
        }
        if let response { replay(response, to: observer) }
    }

    /// A rejected response remains available for its owning instance to register later.
    /// Monitors validate the account and user themselves. Clearing after any registration would let
    /// an unrelated instance consume the tap before the matching instance has finished starting.
    /// Identity checking prevents a replay from clearing a newer response cached by a callback.
    private static func replay(_ response: UNNotificationResponse, to observer: PushNotificationMonitoring) {
        guard observer.didReceiveNotification(response: response, completionHandler: {}) else { return }
        lock.withLock {
            if pendingResponse === response { pendingResponse = nil }
        }
    }

    /// Retains live monitors only for the duration of this callback pass.
    private static func currentMonitors() -> [PushNotificationMonitoring] {
        lock.withLock {
            pushNotificationMonitors.allObjects.compactMap { $0 as? PushNotificationMonitoring }
        }
    }

    /// Installs the existing delegate hooks and asks APNs for a device token.
    /// Permission prompting remains the monitor's responsibility.
    static func configureAutomatically() {
        UIApplication.swizzleDidRegisterForDeviceToken()
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.swizzleNotificationCenterGetDelegate()
    }

    /// Every live instance receives the same OS token and owns its own backend publication.
    static func didRegister(deviceToken: Data) {
        for monitor in currentMonitors() { monitor.setPushToken(deviceToken) }
    }

    /// Offers the response until one monitor claims it. Only that monitor invokes the OS completion.
    /// If none claims it, complete now and cache the tap; replay uses an empty completion.
    /// Continuing after a claim, or reusing the OS completion during replay, would call it twice.
    static func didReceive(
        _ response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        for monitor in currentMonitors() {
            let didHandle = monitor.didReceiveNotification(response: response, completionHandler: completionHandler)
            if didHandle {
                // A handled live response supersedes the older cached tap, as in the existing routing policy.
                lock.withLock { pendingResponse = nil }
                return
            }
        }
        lock.withLock { pendingResponse = response }
        completionHandler()
    }

    /// Preserves the platform-specific presentation options for recognized Userpilot notifications.
    static func willPresent(
        _ parsedNotification: UserpilotNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list])
        } else {
            completionHandler(.alert)
        }
    }
}
