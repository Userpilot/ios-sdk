//
//  UserPilot.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
// [Brief Description]
// UserPilot An object that manages UserPilot tracking and rendering of experience content, for your app.
//

import UIKit

public class UserPilot: NSObject {

    // MARK: - Properties
    private lazy var settingsVerifier = container.resolve(SettingsVerifing.self)
    private lazy var analyticsPublisher = container.resolve(AnalyticsPublishing.self)
    private lazy var storage = container.resolve(DataStoring.self)
    private lazy var socketManager = container.resolve(SocketEvents.self)

    let container = DIContainer()
    let config: Config

    var sessionID: UUID?
    var isActive: Bool { sessionID != nil }

    // MARK: - init
    /*
     Creates an instance of UserPilot.
     Parameter config: `Config` object for this instance, containing initialization options.
     */
    public init(config: Config) {
        self.config = config
        super.init()

        initializeContainer()
        setupSettings()
        config.logger.info("🌏 UserPilot SDK %{public}@ initialized", version())
    }

}

// MARK: - Public methods
extension UserPilot {

    /*
     Get the current version of the UserPilot SDK.
     Returns: Current version of the UserPilot SDK.
     */
    public static func version() -> String {
        return userpilotVersion
    }

    /*
     Get the current version of the UserPilot SDK.
     Returns: Current version of the UserPilot SDK.
     */
    public func version() -> String {
        return UserPilot.version()
    }

}

// MARK: - Setup methods
extension UserPilot {

    /// setup managers and sengletons
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

    /// get customer state and settings
    private func setupSettings() {
        // settingsVerifier.verifySettings {
        // }
    }

    /// In case the userID there, join to channel
    public func initialize() {
        checkSocketState()
    }

    private func checkSocketState() {
        if storage.userID.isNotEmpty {
            socketManager.connect()
        }
    }

}

// MARK: - Tracking APIs
extension UserPilot {

    /*
     Identify the user and determine if they should see Appcues content.
     - Parameters:
     - userID: Unique value identifying the user.
     - properties: Optional properties that provide additional context about the user.
     - company: Optional company that provide additional context about the user.
     */
    public func identify(userID: String, properties: [String: Any]? = nil, company: [String: Any]? = nil) {
        let event = Event(type: .identify(userID), properties: properties, company: company)
        analyticsPublisher.identify(event, isAnonymous: false)
    }

    /*
     Generate a unique ID for the current user when there is not a known identity to use in
     the `identify` call. This will cause the SDK to begin tracking activity and checking for
     qualified content.
     */
    public func anonymous() {
        let event = Event(type: .identify("anonymous:\(config.anonymousIDFactory())"))
        analyticsPublisher.identify(event, isAnonymous: true)
    }

    /*
     Track a custom event for an action taken by a user.
     - Parameters:
     - name: Name of the event.
     - properties: Optional properties that provide additional context about the event.
     */
    public func track(name: String, properties: [String: Any]? = nil) {
        if !socketManager.isSocketOpened { return }
        analyticsPublisher.publish(Event(type: .event(name), properties: properties))
    }

    /*
     Track an screen viewed by a user manually.
     - Parameters:
     - title: Title of the screen.
     - properties: Optional properties that provide additional context about the screen view.
     */
    public func screen(_ title: String, properties: [String: Any]? = nil) {
        analyticsPublisher.publish(Event(type: .screen(title), properties: properties))
    }

    /*
     Called when user logout.
     Clears out the current user in this session. Can be used when the user logs out of your application.
     */
    public func reset() {
        analyticsPublisher.reset()
        storage.userID = ""
        storage.isAnonymous = true
    }

}
