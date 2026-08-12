//
//  PushNotificationMonitor.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  The `PushNotificationMonitor` is responsible for managing push notifications,
//  including push token management, push status monitoring, and handling notification responses. It also integrates
//  with analytics events and socket communication for seamless push notification functionality.
//

import UIKit

/// `PushNotificationMonitoring` protocol defines the methods required to handle push notifications, token
/// management, and status updates.
internal protocol PushNotificationMonitoring: AnyObject {

    /// The current push authorization status.
    var pushAuthorizationStatus: UNAuthorizationStatus { get }

    /// A boolean indicating whether push notifications are enabled.
    var pushEnabled: Bool { get }

    /// Sets the push token for the device.
    ///
    /// - Parameter deviceToken: The device token received from APNs.
    func setPushToken(_ deviceToken: Data?)

    /// Re-publishes the current device token even when its value has not changed.
    ///
    /// `setPushToken(_:)` is value-guarded and is therefore a no-op for a returning user whose
    /// token is unchanged. This re-asserts the token ↔ user pairing on the backend.
    func resyncPushToken()

    /// Refreshes the push authorization status and calls the completion handler with the updated status.
    ///
    /// - Parameter completion: A closure that is called with the updated authorization status.
    func refreshPushStatus(completion: ((UNAuthorizationStatus) -> Void)?)

    /// Handles the received notification and calls the provided completion handler.
    ///
    /// - Parameters:
    ///   - response: The response to the push notification.
    ///   - completionHandler: A closure that should be called after processing the notification.
    ///
    /// - Returns: A boolean indicating whether the notification was successfully handled.
    func didReceiveNotification(response: UNNotificationResponse, completionHandler: @escaping () -> Void) -> Bool

    /// Attempts to handle a deferred notification response.
    ///
    /// - Returns: A boolean indicating whether the deferred response was successfully processed.
    @discardableResult
    func attemptDeferredNotificationResponse() -> Bool
}

/// `PushNotificationMonitor` is responsible for managing push notifications,
/// including token management, push status updates,
/// and handling received notifications. It interacts with the `PushNotificationAutoConfig` and
/// publishes analytics events.
internal class PushNotificationMonitor: PushNotificationMonitoring, SocketSubscription {

    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let storage: DataStoring
    private let analyticsPublisher: AnalyticsPublishing
    private let socketManager: SocketEvents

    // MARK: - Push Token Management

    private(set) var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    // cached token when it comes from OS, and keep it cached so if user is switched, then send it to new user
    private var cachedToken: Data?

    /// A computed property indicating whether push notifications are enabled.
    var pushEnabled: Bool {
        pushAuthorizationStatus == .authorized && storage.pushToken.isNotEmpty
    }

    private var deferredNotification: UserpilotNotification?
    // Later, we could make this as configuration option,
    // to request the permission many times till we get it.
    private var didRequestPermissions = false

    /// Initializes the `PushNotificationMonitor` with dependencies from the dependency injection container.
    ///
    /// - Parameter container: The dependency injection container.
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.socketManager = container.resolve(SocketEvents.self)

        PushNotificationAutoConfig.register(observer: self)
        socketManager.registerCallback(self)
    }

    // MARK: - Push Token Management

    /// Sets the push token and stores it in the analytics publisher or caches it for later use.
    ///
    /// - Parameter deviceToken: The device token received from APNs.
    func setPushToken(_ deviceToken: Data?) {
        // Cache the token in all cases so in next identify in same session, we will sync it
        cachedToken = deviceToken
        guard
            let newToken = deviceToken.map(hexString(from:)),
            storage.pushToken != newToken
        else {
            return
        }

        if analyticsPublisher.canRequestEvent {
            publishTokenEvent(newToken)
        }
    }

    /// Re-publishes the current device token even when its value has not changed.
    ///
    /// `setPushToken(_:)` is value-guarded, so a returning user whose APNs token did not change
    /// would otherwise never re-pair token ↔ user on the backend. Driven by `AnalyticsPublisher`
    /// after it forwards an identify that carries no new user data.
    func resyncPushToken() {
        // Prefer the token the OS handed us this launch; fall back to the persisted one for a warm
        // start where `didRegisterForRemoteNotificationsWithDeviceToken` has not fired yet.
        guard
            let token = cachedToken.map(hexString(from:)) ?? storage.pushToken,
            token.isNotEmpty,
            analyticsPublisher.canRequestEvent
        else {
            return
        }

        publishTokenEvent(token)
    }

    /// Hex representation of a raw APNs device token.
    private func hexString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    /// Publishes the `user_token` event for the given hex token.
    private func publishTokenEvent(_ token: String) {
        analyticsPublisher.publishInternalSDKEvent(
            PushNotificationTokenEvent(
                appToken: config.token,
                userId: storage.userId,
                token: token),
            socketSubscription: self)
    }

    /// Handles the socket event for sending the push token.
    ///
    /// - Parameters:
    ///   - eventName: The name of the event.
    ///   - payload: The payload of the event.
    ///   - message: The message associated with the event.
    ///   - status: A boolean indicating the event's success or failure.
    func onSocketEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ status: Bool
    ) {
        if eventName == SDKEventsName.pushNotificationToken.rawValue {
            storage.pushToken = payload?["token"] as? String
        }
    }

    /// Called when the socket is opened, and the push token is set if cached.
    func onSocketOpened() {
        refreshPushStatus()
        if let cachedToken {
            setPushToken(cachedToken)
        }
        attemptDeferredNotificationResponse()
    }

    // MARK: - Refresh Push Status

    /// Refreshes the push notification status by querying the UNUserNotificationCenter.
    ///
    /// - Parameter completion: An optional closure that is called with the updated authorization status.
    func refreshPushStatus(completion: ((UNAuthorizationStatus) -> Void)? = nil) {
        if config.disableRequestPushPermission || didRequestPermissions { return }
        didRequestPermissions = true
        #if targetEnvironment(simulator)
        print("🔧 Running on Simulator - push notification settings are not available.")
        // Optionally simulate a status (e.g., .notDetermined or .authorized)
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            completion?(.authorized)
        }
        #else
        print("📱 Running on Device - checking push notification settings...")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.handlePushStatusUpdate(settings.authorizationStatus, completion: completion)
            }
        }
        #endif
    }

    /// Handles the updated push status and executes any necessary logic.
    ///
    /// - Parameters:
    ///   - newStatus: The new push authorization status.
    ///   - completion: An optional closure that is called with the updated status.
    private func handlePushStatusUpdate(
        _ newStatus: UNAuthorizationStatus,
        completion: ((UNAuthorizationStatus) -> Void)?
    ) {
        let shouldPublish = self.pushAuthorizationStatus != newStatus
        self.pushAuthorizationStatus = newStatus

        if shouldPublish || newStatus == .notDetermined {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            // Request permission for push notifications
            UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] (granted, _) in
                if granted {
                    self?.config.logger.info("Push notification permission granted.")
                    // Register for remote notifications if permission is granted
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                    self?.config.logger.info("Permission denied or failed to request.")
                }
            }
        }

        completion?(newStatus)
    }

    // MARK: - Notification Handling

    /// Handles a received push notification response and processes the notification.
    ///
    /// - Parameters:
    ///   - response: The response to the notification.
    ///   - completionHandler: A closure that should be called after processing the notification.
    ///
    /// - Returns: A boolean indicating whether the notification was successfully handled.
    @discardableResult
    func didReceiveNotification(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) -> Bool {
        return processNotification(response.notification.request.content.userInfo, completionHandler: completionHandler)
    }

    /// Processes a notification and executes the appropriate response based on the notification's content.
    ///
    /// - Parameters:
    ///   - userInfo: The user info dictionary containing the notification's payload.
    ///   - completionHandler: An optional closure to be executed after processing.
    ///
    /// - Returns: A boolean indicating whether the notification was successfully handled.
    private func processNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: (() -> Void)?
    ) -> Bool {
        config.logger.info("Push response received:\n%{private}@", userInfo.description)

        guard
            let parsedNotification = UserpilotNotification(userInfo: userInfo),
            parsedNotification.notificationType == "userpilot-notification"
        else { return false } // Not a Userpilot push notification

        guard let userpilot = userpilot else {
            return false  // Early exit if userpilot is nil
        }

        if let appToken = parsedNotification.appToken, !appToken.isEmpty, appToken != config.token {
            return false
        }

        // If there’s an active session and a user Id mismatch, let another instance
        // try to handle the response instead of swallowing it.
        guard parsedNotification.userId == storage.userId else {
            return false
        }

        // Handle deferred notification if analytics event is not yet allowed
        guard analyticsPublisher.canRequestEvent else {
            deferredNotification = parsedNotification
            completionHandler?()
            return true
        }

        // Process the notification and respond accordingly
        executeNotificationResponse(
            userpilot: userpilot,
            parsedNotification: parsedNotification,
            completionHandler: completionHandler
        )

        return true
    }

    /// Attempts to process a deferred notification response if it was previously deferred.
    ///
    /// - Returns: A boolean indicating whether the deferred response was successfully processed.
    @discardableResult
    func attemptDeferredNotificationResponse() -> Bool {
        guard
            let parsedNotification = deferredNotification,
            let userpilot = userpilot
        else { return false }

        defer { deferredNotification = nil }

        if let appToken = parsedNotification.appToken, !appToken.isEmpty, appToken != config.token {
            config.logger.info("Deferred notification response skipped")
            return false
        }

        guard parsedNotification.userId == storage.userId else {
            config.logger.info("Deferred notification response skipped")
            return false
        }

        executeNotificationResponse(
            userpilot: userpilot,
            parsedNotification: parsedNotification,
            completionHandler: nil
        )

        return true
    }

    /// Executes the appropriate response to a received notification.
    ///
    /// - Parameters:
    ///   - userpilot: The Userpilot instance managing the navigation.
    ///   - parsedNotification: The parsed notification to be processed.
    ///   - completionHandler: An optional closure to be executed after processing.
    private func executeNotificationResponse(
        userpilot: Userpilot,
        parsedNotification: UserpilotNotification,
        completionHandler: (() -> Void)? = nil
    ) {
        let properties: [String: Any] = [
            "notification_id": Int(parsedNotification.notificationId) ?? 0
        ]

        analyticsPublisher.publishInternalSDKEvent(
            PushNotificationOpenedEvent(payload: properties),
            socketSubscription: self
        )

        if let url = parsedNotification.deeplink {
            navigateToDeepLink(url, userpilot: userpilot)
        }

        completionHandler?()
    }

    /// Navigates to a deep link URL when the notification includes a deep link.
    ///
    /// - Parameters:
    ///   - url: The URL to navigate to.
    ///   - userpilot: The Userpilot instance managing navigation.
    private func navigateToDeepLink(
        _ url: URL,
        userpilot: Userpilot
    ) {
        if let navigationDelegate = userpilot.navigationDelegate {
            navigationDelegate.navigate(to: url)
        } else {
            if url.isHttpOrHttps, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

#if DEBUG
extension PushNotificationMonitor {

    func mockPushStatus(_ status: UNAuthorizationStatus) {
        pushAuthorizationStatus = status
    }

    func setCachedToken(token: Data?) {
        cachedToken = token
    }

    func processNotificationForTesting(
        userInfo: [AnyHashable: Any],
        completionHandler: (() -> Void)? = nil
    ) -> Bool {
        processNotification(userInfo, completionHandler: completionHandler)
    }

}
#endif
