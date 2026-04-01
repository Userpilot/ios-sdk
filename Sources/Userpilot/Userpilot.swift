//
//  Userpilot.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `Userpilot` class is the primary interface for integrating Userpilot SDK into an application.
//  It manages user tracking, event publishing, experience rendering, and various analytics functions,
//  allowing you to deliver personalized, context-aware content based on user actions and data.
//

import ObjectiveC
import UIKit

// swiftlint:disable file_length

/// `Userpilot` manages the lifecycle of the Userpilot SDK and tracks user activity, enabling
/// personalized content delivery.
@objc(Userpilot)
public class Userpilot: NSObject {

    // MARK: - Shared Instance

    /// Backing storage for the shared instance.
    private static var _shared: Userpilot?

    /// Returns the shared `Userpilot` instance that was created during initialization.
    ///
    /// - Important: You must initialize `Userpilot(config:)` before accessing this property.
    ///   Accessing `shared` before initialization will trigger a fatal error.
    @objc
    public static var shared: Userpilot {
        guard let instance = _shared else {
            fatalError("Userpilot SDK has not been initialized. Call Userpilot(config:) first.")
        }
        return instance
    }

    /// Returns `true` if the SDK has been initialized and the shared instance is available.
    @objc
    public static var isInitialized: Bool {
        return _shared != nil
    }

    // MARK: - Properties

    /// A dependency injection container that stores and provides necessary services like analytics,
    /// storage, and networking.
    let container = DIContainer()

    /// Configuration object that holds initialization parameters for the SDK.
    let config: Config

    /// Lazy loading of the `AnalyticsPublishing` instance responsible for publishing user tracking events.
    private lazy var analyticsPublisher = container.resolve(AnalyticsPublishing.self)

    /// Lazy loading of the `DataStoring` instance that manages persistent storage (e.g., user data, preferences).
    private lazy var storage = container.resolve(DataStoring.self)

    /// Lazy loading of the `SocketEvents` instance that manages WebSocket connections and event-driven communication.
    private lazy var socketManager = container.resolve(SocketEvents.self)

    /// Lazy loading of the `SessionMonitoring` instance that manages app lifecycle.
    private lazy var sessionMonitor = container.resolve(SessionMonitoring.self)

    /// Lazy loading of the `ExperiencesPublishing` instance that manages app lifecycle.
    private lazy var experiencesPublisher = container.resolve(ExperiencesPublishing.self)

    /// Lazy loading AutoPropertyDecoratoring
    private lazy var autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)

    /// Lazy loading pushNotificationMonitoring
    private lazy var pushNotificationMonitor = container.resolve(PushNotificationMonitoring.self)

    /// Lazy loading SDK logger
    private lazy var logger = container.resolve(Userpilot.Config.self).logger

    // MARK: - Delegates

    /// The delegate object that handles application screen navigation during experience presentation.
    @objc public weak var navigationDelegate: UserpilotNavigationDelegate?

    /// The delegate object that broadcast analytics events.
    @objc public weak var analyticsDelegate: UserpilotAnalyticsDelegate?

    /// The delegate object that manages and observes experience presentations.
    @objc public weak var experienceDelegate: UserpilotExperienceDelegate?

    // MARK: - Initialization

    /**
     Initializes the `Userpilot` SDK with the provided configuration.
     
     This method sets up the required services such as analytics, storage, and networking, and prepares
     the SDK for tracking and rendering.
     
     - Parameter config: A `Config` object that contains various initialization settings like logging,
     API keys, and anonymous user tracking settings.
     */

    @objc
    public init(config: Config) {
        self.config = config
        super.init()

        // Store as the shared instance for global access (e.g., from swizzled methods)
        Userpilot._shared = self

        // Set up the dependency container and register required services
        initializeContainer()

        // Register pushNotificationMonitoring for push notification auto config
        PushNotificationAutoConfig.register(observer: pushNotificationMonitor)

        // Start Auto capture
        checkAutoCapture()

        // Log the initialization of the SDK with the current version
        config.logger.info("🌏 Userpilot SDK initialized, version: %{public}@", version())
    }

    // MARK: - Setup Methods

    /**
     Initializes the DI (Dependency Injection) container and registers required services.
     
     This method sets up lazy initialization for essential SDK services like `DataStoring`,
     `Networking`, `SocketEvents`, and more.
     By using lazy registration, the services are only created when they are first used, improving performance.
     */
    internal func initializeContainer() {
        container.owner = self
        container.register(Config.self, value: config)
        container.registerLazy(AutoPropertyDecoratoring.self, initializer: AutoPropertyDecorator.init)
        container.registerLazy(SocketEvents.self, initializer: SocketManager.init)
        container.registerLazy(SDKSettingsDetectoring.self, initializer: SDKSettingsDetector.init)
        container.registerLazy(ThemeHandling.self, initializer: ThemeHandler.init)
        container.registerLazy(ImageLoading.self, initializer: ImageLoader.init)
        container.registerLazy(ScreenNameTracking.self, initializer: ScreenNameTracker.init)
        container.registerLazy(ScreenTimeTracking.self, initializer: ScreenTimeTracker.init)
        container.registerLazy(AutoCapturing.self, initializer: AutoCapturer.init)
        container.registerEager(DataStoring.self, initializer: Storage.init)
        container.registerEager(AnalyticsPublishing.self, initializer: AnalyticsPublisher.init)
        container.registerEager(PushNotificationMonitoring.self, initializer: PushNotificationMonitor.init)
        container.registerEager(ExperiencesPublishing.self, initializer: ExperiencesPublisher.init)
        container.registerEager(SessionMonitoring.self, initializer: SessionMonitor.init)
    }
}

// MARK: - Public Methods

extension Userpilot {

    /**
     Retrieves the current version of the Userpilot SDK as a string.
     
     This method provides the static version of the SDK, useful for logging or debugging purposes.
     
     - Returns: A string representing the current version of the Userpilot SDK.
     */
    @objc(sdkVersion)
    public static func version() -> String {
        return userpilotVersion
    }

    /// Retrieves the current version of the SDK for this instance.
    @objc
    public func version() -> String {
        return Userpilot.version()
    }

}

// MARK: - Tracking APIs

extension Userpilot {

    /**
     Identifies a user to the SDK, enabling personalized content and behavior tracking.
     
     This method allows the SDK to associate analytics and content with a known user by passing their unique `userId`.
     Additional properties and company details can be provided for more context.
     
     - Parameters:
       - userId: A unique identifier for the user, which is used to track their behavior across sessions.
       - properties: An optional dictionary containing user-specific properties like email, role, or age.
       - company: An optional dictionary containing company-specific properties for users associated with company.
     */
    @objc
    public func identify(
        userId: String,
        properties: Payload = nil,
        company: Payload = nil
    ) {
        guard userId.trim().isNotEmpty else {
            config.logger.error("Invalid user id - empty string")
            return
        }
        analyticsPublisher.publish(
            Event(
                type: .identify(userId.trim()),
                properties: properties,
                company: company
            )
        )
    }

    /**
     Tracks an anonymous user session.
     
     This method generates a unique anonymous ID - cache it, allowing the SDK to track behavior and trigger
     relevant content even when the user has not explicitly signed in or identified themselves.
     */
    @objc
    public func anonymous() {
        if storage.anonymousUserId.isEmpty {
            storage.anonymousUserId = "\(config.token)_\(anonymousFactory())"
        }
        identify(userId: storage.anonymousUserId)
    }

    /**
     Tracks a screen view event when a user navigates to a specific screen in the app.
      
     This method records the screen title and sends it to the analytics service for tracking
     user activity and triggering content.
      
     - Parameter title: The title of the screen that the user has viewed.
     */
    @objc
    public func screen(_ title: String) {
        guard !config.enableScreenAutoCapture else {
            config.logger.error("Manual screen tracking is disabled when enableScreenAutocapture is enabled")
            return
        }
        guard title.trim().isNotEmpty else {
            config.logger.error("Invalid screen title - empty string")
            return
        }
        analyticsPublisher.publish(Event(type: .screen(title)))
    }

    /**
     Tracks a custom event based on a user action.
     
     This method allows developers to track any arbitrary action taken by the user, such as button clicks,
     form submissions, or purchases.
     The event is recorded and sent to the analytics service for further analysis or content triggering.
     
     - Parameters:
       - name: The name of the custom event (e.g., "purchase", "button_click").
       - properties: An optional dictionary containing additional context or metadata related to the event.
     */
    @objc
    public func track(
        eventName: String,
        properties: Payload = nil
    ) {
        guard eventName.trim().isNotEmpty else {
            config.logger.error("Invalid event name - empty string")
            return
        }
        analyticsPublisher.publish(
            Event(
                type: .event(eventName),
                properties: properties
            )
        )
    }

    /**
     Logs the user out and clears their session data.
     
     This method should be called when the user logs out of the application.
     It calls clean method and close user socket.
     */
    @objc
    public func logout() {
        storage.temporaryUser = nil
        storage.user = ""
        analyticsPublisher.logout(socketState: .shuttingDown, shouldClearCachedIdentifyEvent: true)
        clean()
    }

    /**
     This function gathers application settings (such as the SDK version and user data) into a dictionary,
     converts it into a JSON string, and logs it for debugging purposes.
     */
    @objc
    public func settings() -> [String: Any] {
        var autoPropertiesDict: [String: Any]?
        var appPropertiesDict: [String: Any]?
        var user: [String: Any]?

        // Convert the JSON strings to dictionaries
        if let autoPropertiesData = autoPropertyDecorator.autoProperties.toJSONString()?.data(using: .utf8) {
            autoPropertiesDict = (try? JSONSerialization.jsonObject(
                with: autoPropertiesData, options: [])) as? [String: Any]
        }

        if let appPropertiesData = autoPropertyDecorator.appProperties.toJSONString()?.data(using: .utf8) {
            appPropertiesDict = (try? JSONSerialization.jsonObject(
                with: appPropertiesData, options: [])) as? [String: Any]
        }

        if let userData = storage.user.data(using: .utf8) {
            user = (try? JSONSerialization.jsonObject(with: userData, options: [])) as? [String: Any]
        }

        // Create the dictionary for settings
        let settings: [String: Any] = [
            "SDK version": version(),
            "Token": config.token,
            "User": user ?? [:],
            "Auto properties": autoPropertiesDict ?? [:],
            "App properties": appPropertiesDict ?? [:]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .withoutEscapingSlashes) {
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("⚙️ Settings -> %{public}@", jsonString)
            }
        }

        return settings
    }

    // MARK: - SDK APIs

    /**
     Clear user session data.
     
     This method should be called when the user logs out or when identify called with new userId.
     It resets the session state, clears user-related data, and ensures no further tracking occurs for
     the logged-out user.
     */
    internal func clean() {
        storage.pushToken = nil
        storage.userId = ""
        storage.user = ""
    }
}

// MARK: - Experiences

extension Userpilot {

    /**
     Manually starts an experience within the client application using the provided experience token.
     
     - Parameters:
       - experienceId: unique identifier for the experience to be launched, this ID should be provided
        by the backend or obtained during experience configuration.
     */
    @objc
    public func triggerExperience(_ experienceId: String) {
        guard experienceId.trim().isNotEmpty else {
            config.logger.error("Invalid experience id - empty string")
            return
        }
        experiencesPublisher.triggerExperience(experienceId)
    }

    /**
     Manually ends an experience within from the client application.
     */
    @objc
    public func endExperience() {
        experiencesPublisher.endExperience(manualClose: true)
    }
}

// MARK: - Push notifications

extension Userpilot {

    /// Enables automatic configuration of push notifications for Userpilot.
    /// This method sets up the push notification settings automatically.
    @objc
    public static func enableAutomaticPushConfig() {
        PushNotificationAutoConfig.configureAutomatically()
    }

    /// Provides the APNs device token to Userpilot for push notification tracking.
    ///
    /// - Parameter deviceToken: The device token received from Apple's Push Notification Service (APNs).
    ///   This token is used for registering the device with Userpilot to receive push notifications.
    @objc
    public func setPushToken(_ deviceToken: Data?) {
        pushNotificationMonitor.setPushToken(deviceToken)
    }

    /// Called when the client app receives a push notification.
    ///
    /// - Parameters:
    ///   - response: The `UNNotificationResponse` object containing information about the
    ///   notification that was received.
    ///   - completionHandler: A closure to be executed after processing the notification. This block
    ///   must be called when the app finishes processing the notification.
    ///
    /// - Returns: A `Bool` indicating whether Userpilot should automatically handle the
    /// completion block. If `true` is returned, Userpilot will call the `completionHandler` automatically.
    ///  If `false` is returned, you should call `completionHandler` after processing the user's response.
    public func didReceiveNotification(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) -> Bool {
        return pushNotificationMonitor.didReceiveNotification(
            response: response,
            completionHandler: completionHandler
        )
    }

}

// MARK: - Auto capture

extension Userpilot {

    /// Internal access to the automatic capture engine (screen + interaction hooks).
    internal var autoCaptureEngine: AutoCapturing {
        return container.resolve(AutoCapturing.self)
    }

    /// Check auto capture configuration and initialize engines if enabled.
    public func checkAutoCapture() {
        let config = container.resolve(Userpilot.Config.self)
        let screenAutocaptureEnabled = config.enableScreenAutoCapture
        let interactionEnabled = config.enableInteractionAutoCapture

        if screenAutocaptureEnabled || interactionEnabled {
            _ = autoCaptureEngine
        }
    }
}

// MARK: - Autocapture Stop / Resume (thin facade; implementation in AutocaptureStopResume)

extension Userpilot {

    /// Stops automatic screen and interaction capture. No events are recorded until `resumeAutoCapture()` is called.
    @objc
    public static func stopAutoCapture() {
        AutocaptureViewConfiguration.stopAutoCapture()
    }

    /// Resumes automatic screen and interaction capture after a previous `stopAutoCapture()`.
    @objc
    public static func resumeAutoCapture() {
        AutocaptureViewConfiguration.resumeAutoCapture()
    }
}

// MARK: - Autocapture View Configuration (thin facade; implementation in AutocaptureViewConfiguration)

extension Userpilot {

    @objc
    public static func userpilotSetIgnoreInteractions(_ value: Bool, for responder: UIResponder) {
        AutocaptureViewConfiguration.setIgnoreInteractions(value, for: responder)
    }

    @objc
    public static func userpilotSetIgnoreInnerHierarchy(_ value: Bool, for responder: UIResponder) {
        AutocaptureViewConfiguration.setIgnoreInnerHierarchy(value, for: responder)
    }

    @objc
    public static func userpilotSetRedactText(_ value: Bool, for responder: UIResponder) {
        AutocaptureViewConfiguration.setRedactText(value, for: responder)
    }

    @objc
    public static func userpilotSetRedactAccessibilityLabel(_ value: Bool, for responder: UIResponder) {
        AutocaptureViewConfiguration.setRedactAccessibilityLabel(value, for: responder)
    }

    @objc
    public static func userpilotSetIgnoreInteractionsDefault(_ value: Bool, for responderType: UIResponder.Type) {
        AutocaptureViewConfiguration.setIgnoreInteractionsDefault(value, for: responderType)
    }

    @objc
    public static func userpilotSetIgnoreInnerHierarchyDefault(_ value: Bool, for responderType: UIResponder.Type) {
        AutocaptureViewConfiguration.setIgnoreInnerHierarchyDefault(value, for: responderType)
    }
}

// swiftlint:enable file_length
