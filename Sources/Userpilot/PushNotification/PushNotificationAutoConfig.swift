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
        lock.unlock()

        // Process any cached response that arrived before this monitor existed.
        guard let pendingResponse = pendingResponse else { return }

        let didHandle = observer.didReceiveNotification(
            response: pendingResponse,
            completionHandler: {}
        )

        // Consume it only if this observer actually claimed it. A monitor
        // declines a response belonging to another token or another user, and
        // clearing the cache regardless would let the first monitor to register
        // swallow a response meant for an instance still coming up.
        guard didHandle else { return }

        lock.lock()
        if self.response === pendingResponse {
            self.response = nil
        }
        lock.unlock()
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
    /// Registered monitors are tried until one handles the response. A response
    /// nobody can handle is cached and replayed to the next monitor to register,
    /// so a tap that arrives before the SDK is configured is not lost.
    ///
    /// Responses are not routed by app token here: every monitor already compares
    /// the payload's token against its own instance before claiming a response, so
    /// looking the instance up first only duplicated that check — and when the
    /// instance for that token did not exist yet, it dropped the response instead
    /// of caching it. That is the normal cold-start ordering for the Flutter,
    /// React Native and Capacitor wrappers, which configure the SDK from their own
    /// runtime, well after the notification is delivered.
    ///
    /// - Parameters:
    ///   - response: The response to the notification containing the user's interaction with the notification.
    ///   - completionHandler: A closure to be executed when the notification has been handled.
    static func didReceive(
        _ response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Stop at the first monitor that claims the response. Only one monitor
        // executes the completion handler so we don't trigger UIKit's "called
        // completionHandler more than once" assertion.
        for monitor in currentMonitors() {
            let didHandle = monitor.didReceiveNotification(
                response: response,
                completionHandler: completionHandler
            )
            if didHandle {
                // A newer response was handled, so an older cached one is stale.
                lock.lock()
                self.response = nil
                lock.unlock()
                return
            }
        }

        // Nobody could take it — usually because the instance it belongs to has not
        // been configured yet. Hold it for the next monitor to register, which
        // replays it from `register(observer:)`.
        lock.lock()
        self.response = response
        lock.unlock()

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
