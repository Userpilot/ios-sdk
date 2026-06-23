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
    /// All registered push notification observers. Held weakly via the table so
    /// observers can be deallocated by their owning `Userpilot` instance without
    /// leaking. `NSHashTable` already de-duplicates by object identity, so
    /// re-registering the same monitor (e.g. on configuration refresh) is a no-op.
    private static let pushNotificationMonitors = NSHashTable<AnyObject>.weakObjects()

    /// Lock guarding `pushNotificationMonitors` and `response`.
    private static let lock = NSLock()

    // In some case like in plugins(ReactNative and FLutter), didReceive called
    // while pushNotificationMonitor is not set.
    private static var response: UNNotificationResponse?

    /// Registers a `PushNotificationMonitoring` observer to handle push notifications.
    ///
    /// Multi-instance: each `Userpilot` instance's monitor registers on init, so the
    /// process-wide observer list contains one entry per live instance. `setPushToken`
    /// fans out to every registered monitor; tokenized notification responses route
    /// directly to the matching `Userpilot` instance.
    ///
    /// Re-registering the same monitor object is a no-op thanks to the underlying
    /// `NSHashTable` identity-based deduplication.
    ///
    /// - Parameter observer: The `PushNotificationMonitoring` instance that will handle push notifications.
    static func register(observer: PushNotificationMonitoring) {
        lock.lock()
        // `NSHashTable.weakObjects()` is keyed by `ObjectIdentifier`-equivalent
        // pointer identity, so adding the same observer twice does not duplicate.
        pushNotificationMonitors.add(observer as AnyObject)
        let pendingResponse = response
        if pendingResponse != nil {
            response = nil
        }
        lock.unlock()

        // Process any cached response that arrived before this monitor existed.
        if let pendingResponse = pendingResponse {
            _ = observer.didReceiveNotification(
                response: pendingResponse,
                completionHandler: {}
            )
        }
    }

    /// Returns a snapshot of all currently registered monitors.
    private static func currentMonitors() -> [PushNotificationMonitoring] {
        lock.lock()
        let snapshot = pushNotificationMonitors.allObjects.compactMap {
            $0 as? PushNotificationMonitoring
        }
        lock.unlock()
        return snapshot
    }

    /// Configures the app to automatically handle push notifications by swizzling necessary methods.
    /// This method registers the app for remote notifications and modifies the notification center delegate.
    static func configureAutomatically() {
        UIApplication.swizzleDidRegisterForDeviceToken()
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.swizzleNotificationCenterGetDelegate()
    }

    /// Called when the device successfully registers for push notifications and receives the device token.
    /// This method passes the device token to every registered `PushNotificationMonitoring` observer
    /// so each `Userpilot` instance can forward the token to its own backend.
    ///
    /// - Parameter deviceToken: The device token received from APNs (Apple Push Notification Service).
    static func didRegister(deviceToken: Data) {
        for monitor in currentMonitors() {
            monitor.setPushToken(deviceToken)
        }
    }

    /// Called when a push notification is received and handled by the app.
    /// If the response contains a Userpilot app token, it is routed directly to the
    /// matching instance. Otherwise, registered monitors are tried until one handles
    /// the response. If no monitor handles it, the completion handler is executed
    /// without any special handling.
    ///
    /// - Parameters:
    ///   - response: The response to the notification containing the user's interaction with the notification.
    ///   - completionHandler: A closure to be executed when the notification has been handled.
    static func didReceive(
        _ response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if
            let parsedNotification = UserpilotNotification(userInfo: userInfo),
            let appToken = parsedNotification.appToken,
            !appToken.isEmpty {
            guard let instance = Userpilot.instance(forToken: appToken) else {
                completionHandler()
                return
            }

            let didHandle = instance.didReceiveNotification(
                response: response,
                completionHandler: completionHandler
            )
            if !didHandle {
                completionHandler()
            }
            return
        }

        // Snapshot monitors and, when there are none, cache the response under the SAME
        // lock acquisition. This serialises against `register(observer:)`: a registering
        // monitor is either already in this snapshot (delivered below), or its `register`
        // runs after we cache and therefore observes `response` and replays it. Splitting
        // these into two separate lock acquisitions would let a monitor register in the
        // gap and miss the push.
        lock.lock()
        let monitors = pushNotificationMonitors.allObjects.compactMap {
            $0 as? PushNotificationMonitoring
        }
        if monitors.isEmpty {
            // No monitor yet (e.g. plugin lifecycle race) — cache so the next monitor to
            // register can replay the response.
            self.response = response
        }
        lock.unlock()

        guard !monitors.isEmpty else {
            completionHandler()
            return
        }

        // Stop at the first monitor that claims the response. Only one monitor
        // executes the completion handler so we don't trigger UIKit's "called
        // completionHandler more than once" assertion.
        for monitor in monitors {
            let didHandle = monitor.didReceiveNotification(
                response: response,
                completionHandler: completionHandler
            )
            if didHandle { return }
        }
        completionHandler()
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
