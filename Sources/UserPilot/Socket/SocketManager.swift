//
//  SocketManager.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `SocketManager` handles socket events and state management for WebSocket connections.
//

import Foundation
import SwiftPhoenixClient

// MARK: - Protocols

/**
 `SocketEvents` defines methods and properties for managing WebSocket connections and events.
 */
internal protocol SocketEvents: AnyObject {
    var isSocketOpened: Bool { get }
    var isJoiningSocket: Bool { get }
    var didErrorOccurred: Bool { get }

    func connect()
    func close()

    func publish(_ eventName: String, payload: [String: Any]?, shouldCloseSocket: Bool,
                 socketSubscription: SocketSubscription?)
    func registerCallback(_ socketSubscription: SocketSubscription)
}

internal extension SocketEvents {

    func publish(_ eventName: String, payload: [String: Any]?, shouldCloseSocket: Bool = false,
                 socketSubscription: SocketSubscription? = nil) {
        publish(eventName, payload: payload, shouldCloseSocket: shouldCloseSocket,
                socketSubscription: socketSubscription)
    }
}

/**
 `SocketSubscription` defines a callback interface for handling socket event notifications.
 */
internal protocol SocketSubscription: AnyObject {
    func onSocketClosed()
    func onSocketOpened()
    func onSocketEventSent(_ event: String, _ message: Message, _ status: Bool)
}

extension SocketSubscription {
    func onSocketClosed() {
        // Default implementation (optional)
    }

    func onSocketOpened() {
        // Default implementation (optional)
    }

    func onSocketEventSent(_ event: String,
                           _ message: Message,
                           _ status: Bool,
                           _ socketSubscription: SocketSubscription) {
        // Default implementation (optional)
    }
}

// MARK: - SocketManager

/**
 `SocketManager` is responsible for managing WebSocket connections, sending events, and handling responses.
 */
internal class SocketManager {

    // MARK: - Properties

    /// URL for the WebSocket connection.
    private let socketURL = "wss://analytex-dev-nxtapp-8794.userpilot.io/mobile/v1/events/websocket"

    /// The WebSocket instance for handling connections.
    private var phoenixSocket: Socket?

    /// The channel within the WebSocket connection.
    private var phoenixChannel: Channel?

    /// SDK instance.
    private weak var userPilot: UserPilot?

    /// SDK Config.
    private let config: UserPilot.Config

    /// SDK storage.
    private let storage: DataStoring

    /// Auto property decorator.
    private let autoPropertyDecorator: AutoPropertyDecoratoring

    /// SDK logger
    private let logger: Logging

    /// SDK storage.
    private let sdkSettingsDetector: SDKSettingsDetectoring

    /// socket susbcriber
    @Multicast var socketSubscription: SocketSubscription

    /// getting SDK settings
    private var isGettingSettings = false

    /// track error state
    private var isErrorOccurred = false

    // MARK: - Initialization

    /**
     Initializes the `SocketManager` with dependencies provided by the `DIContainer`.
     
     - Parameter container: The dependency injection container.
     */
    init(container: DIContainer) {
        self.userPilot = container.owner
        self.config = container.resolve(UserPilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.sdkSettingsDetector = container.resolve(SDKSettingsDetectoring.self)
        self.logger = config.logger
    }

}

// MARK: - Socket Connection and Callbacks

extension SocketManager {

    /**
     Opens a WebSocket connection and joins the specified channel.
     
     - Parameter completion: A closure that is called when the connection attempt completes.
     */
    private func openSocket() {
        guard
            let autoProperties = autoPropertyDecorator.autoProperties.toJSONString(),
            let appProperties = autoPropertyDecorator.appProperties.toJSONString()
        else { return }

        let socketProperties: [String: Any] = [
                SocketManager.tokenKey: config.token,
                SocketManager.userIDKey: storage.userID,
                SocketManager.sdkVersionKey: userPilot?.version() ?? "",
                SocketManager.autoPropertiesKey: autoProperties,
                SocketManager.appPropertiesKey: appProperties
        ]

        phoenixSocket = Socket(socketURL, params: socketProperties)
        guard let phoenixSocket = phoenixSocket else { return }

        // Setup delegates for socket events
        phoenixSocket.delegateOnOpen(to: self) { (self) in
            self.logger.info("🚀 SOCKET opened")
        }

        phoenixSocket.delegateOnClose(to: self) { (self) in
            self.logger.error("🛑 SOCKET closed")
            self.$socketSubscription.invoke { $0.onSocketClosed() }
        }

        phoenixSocket.delegateOnError(to: self) { (self, error) in
            let (error, _) = error
            self.isErrorOccurred = true
            self.logger.error("🛑 SOCKET error - details %{public}@", error.localizedDescription)
            self.closeSocket()
        }

        // Setup socket logger
        phoenixSocket.logger = { [weak self] message in
            self?.logger.debug("💡 SOCKET logger - message %{public}@", message)
        }

        // Setup the channel
        let channel = phoenixSocket.channel(SocketManager.channelTopic)

        // Connect to the channel
        phoenixChannel = channel
        phoenixChannel?.join()
            .delegateReceive(SocketManager.successKey, to: self, callback: { (self, _) in
                self.logger.info("🚀 SOCKET channel JOINED")
                self.$socketSubscription.invoke { $0.onSocketOpened() }
            })
            .delegateReceive(SocketManager.errorKey, to: self, callback: { (self, message) in
                self.logger.error("⚠️ SOCKET channel join FAIL: %{public}@", message.payload)
                self.closeSocket()
            })

        phoenixChannel?.onError { [weak self] message in
            self?.isErrorOccurred = true
            self?.logger.debug("🛑 SOCKET Channel error - message %{public}@", message.payload)
            self?.closeSocket()
        }

        phoenixChannel?.onClose { [weak self] message in
            self?.logger.debug("🛑 SOCKET Channel close - message %{public}@", message.payload)
            self?.closeSocket()
        }

        // Connect the socket
        phoenixSocket.connect()
    }

    /**
     Closes the WebSocket connection and leaves the channel.
     
     - Parameter completion: A closure that is called when the disconnection completes.
     */
    private func closeSocket() {
        guard let phoenixSocket = phoenixSocket else { return }
        if let channel = self.phoenixChannel, !channel.isClosed {
            channel.leave()
            phoenixSocket.remove(channel)
        }
        phoenixSocket.disconnect()
    }

}

// MARK: - SocketEvents

extension SocketManager: SocketEvents {

    /// Logic to determine if the channel state is joining
    var isJoiningSocket: Bool {
        phoenixChannel?.isJoining == true || isGettingSettings
    }

    /// Logic to check if the socket is currently open
    var isSocketOpened: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == true
    }

    var didErrorOccurred: Bool {
        isErrorOccurred
    }

    /// Implementation to open a WebSocket connection
    func connect() {
        isGettingSettings = true
        isErrorOccurred = false
        sdkSettingsDetector.fetchSettings { [weak self] in
            guard let self = self else { return }
            self.isGettingSettings = false
            self.openSocket()
        }
    }

    /// Implementation to close the WebSocket connection
    func close() {
        closeSocket()
    }

    /// Implementation to publish an event over the WebSocket
    func publish(_ eventName: String,
                 payload: [String: Any]?,
                 shouldCloseSocket: Bool,
                 socketSubscription: SocketSubscription?) {
        phoenixChannel?
            .push(eventName, payload: payload ?? [:])
            .receive(SocketManager.successKey) { [weak self] message in
                self?.logger.info("✈️ SOCKET message sent: %{public}@\n Payload: %{public}@", eventName, payload ?? [:])
                if let socketSubscription {
                    socketSubscription.onSocketEventSent(eventName, message, true)
                } else {
                    self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, message, true) }
                }
                if shouldCloseSocket { self?.closeSocket() }
            }
            .receive(SocketManager.errorKey) { [weak self] message in
                self?.logger.error("⚠️ SOCKET message send FAIL: %{public}@", message.event)
                if let socketSubscription {
                    socketSubscription.onSocketEventSent(eventName, message, false)
                } else {
                    self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, message, true) }
                }
                if shouldCloseSocket { self?.closeSocket() }
            }
    }

    /// Implementation to register a callback for socket events
    func registerCallback(_ socketSubscription: SocketSubscription) {
        self.socketSubscription = socketSubscription
    }
}

// MARK: - Properties name

internal extension SocketManager {

    // Static constants
    static var channelTopic: String { return "events:*" }
    static var successKey: String { return "ok" }
    static var errorKey: String { return "error" }

    static var tokenKey: String { return "app_token" }
    static var userIDKey: String { return "user_id" }
    static var autoPropertiesKey: String { return "auto_properties" }
    static var appPropertiesKey: String { return "app_properties" }
    static var sdkVersionKey: String { return "sdk_version" }
}
