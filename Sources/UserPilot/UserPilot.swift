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
public class UserPilot: NSObject {

    // MARK: - Properties

    /// A dependency injection container that stores and provides necessary services like analytics, 
    /// storage, and networking.
    let container = DIContainer()

    /// Configuration object that holds initialization parameters for the SDK.
    let config: Config

    /// A UUID representing the current user session. If `nil`, there is no active session.
    var sessionID: UUID?

    /// A Boolean indicating whether the SDK is active (i.e., a session is active). True if `sessionID` is not `nil`.
    var isActive: Bool { sessionID != nil }

    /// Lazy loading of the `SettingsVerifing` instance to verify SDK settings at runtime.
    private lazy var settingsVerifier = container.resolve(SettingsVerifing.self)

    /// Lazy loading of the `AnalyticsPublishing` instance responsible for publishing user tracking events.
    private lazy var analyticsPublisher = container.resolve(AnalyticsPublishing.self)

    /// Lazy loading of the `DataStoring` instance that manages persistent storage (e.g., user data, preferences).
    private lazy var storage = container.resolve(DataStoring.self)

    /// Lazy loading of the `SocketEvents` instance that manages WebSocket connections and event-driven communication.
    private lazy var socketManager = container.resolve(SocketEvents.self)

    // MARK: - Initializer

    /**
     Initializes the `UserPilot` SDK with the provided configuration.
     
     This method sets up the required services such as analytics, storage, and networking, and prepares
     the SDK for tracking and rendering.
     
     - Parameter config: A `Config` object that contains various initialization settings like logging, 
     API keys, and anonymous user tracking settings.
     */
    public init(config: Config) {
        self.config = config
        super.init()

        // Set up the dependency container and register required services
        initializeContainer()

        // Verify and apply necessary SDK settings
        setupSettings()

        // Log the initialization of the SDK with the current version
        config.logger.info("🌏 UserPilot SDK version %{public}@ initialized", version())
    }

}

// MARK: - Public Methods

extension UserPilot {

    /**
     Retrieves the current version of the UserPilot SDK as a string.
     
     This method provides the static version of the SDK, useful for logging or debugging purposes.
     
     - Returns: A string representing the current version of the UserPilot SDK.
     */
    public static func version() -> String {
        return userpilotVersion
    }

    /**
     Retrieves the current version of the UserPilot SDK for the specific instance.
     
     This method returns the SDK version from the context of the instance, though it delegates the 
     call to the static method.
     
     - Returns: A string representing the current version of the SDK for this instance.
     */
    public func version() -> String {
        return UserPilot.version()
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
        container.registerLazy(Networking.self, initializer: NetworkClient.init)
        container.registerLazy(SettingsVerifing.self, initializer: SettingsVerifier.init)
        container.registerLazy(AutoPropertyDecoratoring.self, initializer: AutoPropertyDecorator.init)
        container.registerLazy(SocketEvents.self, initializer: SocketManager.init)
        container.registerLazy(AnalyticsPublishing.self, initializer: AnalyticsPublisher.init)
    }

    /**
     Applies necessary configurations and verifies the SDK settings.
     
     This method uses the `SettingsVerifing` service to ensure that all required settings are valid.
     It can be customized further if specific settings need to be checked or applied.
     */
    private func setupSettings() {
        // Placeholder for settings verification logic
        // settingsVerifier.verifySettings {
        // }
    }

    /**
     Initializes the SDK session by verifying the state of the WebSocket connection and other conditions.
     
     This method should be called after identifying the user or initiating an anonymous session.
     It ensures that the SDK is ready to track events and trigger real-time experiences.
     */
    public func initialize() {
        checkSocketState()
    }

    /**
     Checks whether the WebSocket connection should be established based on the presence of a valid `userID`.
     
     This method verifies if the `userID` exists in the local storage. If it exists, it attempts to connect
     to the WebSocket server.
     */
    private func checkSocketState() {
        // Uncomment and implement logic when userID-based socket management is ready.
        // if storage.userID.isNotEmpty {
        //     socketManager.connect()
        // }
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
       - company: An optional dictionary containing company-specific properties for users associated with organizations.
     */
    public func identify(userID: String, properties: [String: Any]? = nil, company: [String: Any]? = nil) {
        let event = Event(type: .identify(userID), properties: properties, company: company, userID: userID)
        analyticsPublisher.publish(event)
    }

    /**
     Tracks an anonymous user session when a known user identity is unavailable.
     
     This method generates a unique anonymous ID, allowing the SDK to track behavior and trigger relevant content
     even when the user has not explicitly signed in or identified themselves.
     */
    public func anonymous() {
        let event = Event(type: .identify("anonymous:\(config.anonymousIDFactory())"), userID: "")
        analyticsPublisher.publish(event)
    }

    /**
     Tracks when a user views a screen within the app.
     
     This method can be used to manually track screen views for analytics purposes.
     It is especially useful when automatic screen tracking is not available or for custom screens.
     
     - Parameter title: The title of the screen that the user has viewed.
     */
    public func screen(_ title: String) {
        analyticsPublisher.publish(Event(type: .screen(title), userID: storage.userID))
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
    public func track(name: String, properties: [String: Any]? = nil) {
        analyticsPublisher.publish(Event(type: .event(name), properties: properties, userID: storage.userID))
    }

    /**
     Logs the user out and clears their session data.
     
     This method should be called when the user logs out of the application.
     It resets the session state, clears user-related data, and ensures no further tracking occurs for
     the logged-out user.
     */
    public func clean() {
        analyticsPublisher.clean()
        storage.userID = ""
    }
}
