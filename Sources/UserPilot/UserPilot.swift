//
//  UserPilot.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `UserPilot` class is the primary interface for integrating UserPilot SDK into an application.
//  It manages user tracking, event publishing, experience rendering, and various analytics functions,
//  allowing you to deliver personalized, context-aware content based on user actions and data.
//

import UIKit

/// `UserPilot` manages the lifecycle of the UserPilot SDK and tracks user activity, enabling 
/// personalized content delivery.
@objc(UserPilot)
public class UserPilot: NSObject {

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

    /// Lazy loading SDK logger
    private lazy var logger = container.resolve(UserPilot.Config.self).logger

    /// to hold session start state
    private(set) var sessionStarted = false

    // MARK: - Initialization

    /**
     Initializes the `UserPilot` SDK with the provided configuration.
     
     This method sets up the required services such as analytics, storage, and networking, and prepares
     the SDK for tracking and rendering.
     
     - Parameter config: A `Config` object that contains various initialization settings like logging, 
     API keys, and anonymous user tracking settings.
     */
    @objc
    public init(config: Config) {
        self.config = config
        super.init()

        // Set up the dependency container and register required services
        initializeContainer()

        // start session monitoring
        sessionMonitor.start()

        // start experience listener
        experiencesPublisher.start()

        // session start indicator
        sessionStarted = true

        // Log the initialization of the SDK with the current version
        config.logger.info("🌏 UserPilot SDK initialized, version: %{public}@", version())
    }

}

// MARK: - Public Methods

extension UserPilot {

    /**
     Retrieves the current version of the UserPilot SDK as a string.
     
     This method provides the static version of the SDK, useful for logging or debugging purposes.
     
     - Returns: A string representing the current version of the UserPilot SDK.
     */
    @objc(sdkVersion)
    public static func version() -> String {
        return userPilotVersion
    }

    /// Retrieves the current version of the SDK for this instance.
    @objc
    public func version() -> String {
        return UserPilot.version()
    }

    @objc
    public func destroy() {
        logout()
        sessionStarted = false
        sessionMonitor.reset()
    }
}

// MARK: - Setup Methods

extension UserPilot {

    /**
     Initializes the DI (Dependency Injection) container and registers required services.
     
     This method sets up lazy initialization for essential SDK services like `DataStoring`, 
     `Networking`, `SocketEvents`, and more.
     By using lazy registration, the services are only created when they are first used, improving performance.
     */
    private func initializeContainer() {
        container.owner = self
        container.register(Config.self, value: config)
        container.registerLazy(DataStoring.self, initializer: Storage.init)
        container.registerLazy(AutoPropertyDecoratoring.self, initializer: AutoPropertyDecorator.init)
        container.registerLazy(SocketEvents.self, initializer: SocketManager.init)
        container.registerLazy(AnalyticsPublishing.self, initializer: AnalyticsPublisher.init)
        container.registerLazy(SessionMonitoring.self, initializer: SessionMonitor.init)
        container.registerLazy(SDKSettingsDetectoring.self, initializer: SDKSettingsDetector.init)
        container.registerLazy(ExperiencesPublishing.self, initializer: ExperiencesPublisher.init)
        container.registerLazy(ThemeHandling.self, initializer: ThemeHandler.init)
        container.registerLazy(ImageLoading.self, initializer: ImageLoader.init)
        container.registerLazy(FileStoring.self, initializer: FileStorageManager.init)
    }

}

// MARK: - Tracking APIs

extension UserPilot {

    /**
     Identifies a user to the SDK, enabling personalized content and behavior tracking.
     
     This method allows the SDK to associate analytics and content with a known user by passing their unique `userID`.
     Additional properties and company details can be provided for more context.
     
     - Parameters:
       - userID: A unique identifier for the user, which is used to track their behavior across sessions.
       - properties: An optional dictionary containing user-specific properties like email, role, or age.
       - company: An optional dictionary containing company-specific properties for users associated with company.
     */
    @objc
    public func identify(userID: String, properties: Payload = nil, company: Payload = nil) {
        if userID.trim().isEmpty { return }
        let event = Event(type: .identify(userID.trim()), properties: properties, company: company)
        analyticsPublisher.publish(event)
    }

    /**
     Tracks an anonymous user session when a known user identity is unavailable.
     
     This method generates a unique anonymous ID, allowing the SDK to track behavior and trigger relevant content
     even when the user has not explicitly signed in or identified themselves.
     */
    @objc
    public func anonymous() {
        let userID = "\(config.token)_\(anonymousFactory())"
        identify(userID: userID)
    }

    /**
     Tracks a screen view event when a user navigates to a specific screen in the app.
      
     This method records the screen title and sends it to the analytics service for tracking
     user activity and triggering content.
      
     - Parameter title: The title of the screen that the user has viewed.
     */
    @objc
    public func screen(_ title: String) {
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
    public func track(eventName: String, properties: Payload = nil) {
        analyticsPublisher.publish(Event(type: .event(eventName), properties: properties))
    }

    /**
     Logs the user out and clears their session data.
     
     This method should be called when the user logs out of the application.
     It calls clean method and close user socket.
     */
    @objc
    public func logout() {
        updateSessionStartState()
        clean()
        analyticsPublisher.logout(socketState: .shuttingDown, shouldClearCachedIdentifyEvent: true)
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
            // swiftlint:disable:next non_optional_string_data_conversion
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("⚙️ Settings -> %{public}@", jsonString)
            }
        }

        return settings
    }

    // MARK: - SDK APIs

    /**
     Clear user session data.
     
     This method should be called when the user logs out or when identify called with new userID.
     It resets the session state, clears user-related data, and ensures no further tracking occurs for
     the logged-out user.
     */
    internal func clean() {
        storage.userID = ""
        storage.user = User().toJson() ?? ""
    }

    /// Hold SDK state for first initialization
    internal func updateSessionStartState() {
        sessionStarted = false
    }
}

// MARK: - Experiences

extension UserPilot {

    /**
     Manually starts an experience within the client application using the provided experience token.
     
     - Parameters:
       - experienceToken: unique identifier for the experience to be launched, this ID should be provided
        by the backend or obtained during experience configuration.
     */
    @objc
    public func triggerExperience(_ experienceToken: String) {
        experiencesPublisher.triggerExperience(experienceToken)
    }

    /**
     Manually ends an experience within from the client application.
     */
    @objc
    public func endExperience() {
        experiencesPublisher.endExperience()
    }
}
