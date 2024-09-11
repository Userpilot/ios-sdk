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
    var isAllowToOpenSocket: Bool { get }
    var isSocketOpened: Bool { get }
    var isJoiningSocket: Bool { get }

    func connect()
    func close()
    func allowToStart()

    func publish(_ eventName: String, payload: [String: Any]?, shouldCloseSocket: Bool)
    func registerCallback(_ socketSubscription: SocketSubscription)
}

extension SocketEvents {
    func publish(_ eventName: String, payload: [String: Any]?, shouldCloseSocket: Bool = false) {
        publish(eventName, payload: payload, shouldCloseSocket: shouldCloseSocket)
    }
}

/**
 `SocketSubscription` defines a callback interface for handling socket event notifications.
 */
internal protocol SocketSubscription: AnyObject {
    func onSocketClosed()
    func onSocketOpened()
    func onSocketEventSent(_ event: String, _ status: Bool)
}

// MARK: - SocketManager

/**
 `SocketManager` is responsible for managing WebSocket connections, sending events, and handling responses.
 */
internal class SocketManager {

    // MARK: - Properties

    /// URL for the WebSocket connection.
    private let socketURL = "wss://analytex-dev-nxtapp-8755.userpilot.io/mobile/v1/events/"

    /// The WebSocket instance for handling connections.
    private var phoenixSocket: Socket?

    /// The channel within the WebSocket connection.
    private var phoenixChannel: Channel?

    /// A flag indicating whether the socket channel has been successfully opened.
    private var didTryToOpenSocketChannel: Bool = false

    /// Computed property for socket connection parameters.
    private var socketProperties: [String: String] {
        [
            SocketManager.tokenKey: config.token,
            SocketManager.userIDKey: storage.userID
        ]
    }

    /// Computed property for channel-specific parameters.
    private var socketChannelProperties: [String: Any] {
        [
            SocketManager.tokenKey: config.token,
            SocketManager.userIDKey: storage.userID,
            SocketManager.sdkVersionKey: userPilot?.version() ?? "",
            SocketManager.autoPropertiesKey: autoPropertyDecorator.autoProperties,
            SocketManager.appPropertiesKey: autoPropertyDecorator.appProperties
        ]
    }

    private weak var userPilot: UserPilot?
    private let config: UserPilot.Config
    private let storage: DataStoring
    private let autoPropertyDecorator: AutoPropertyDecoratoring
    private let logger: Logging

    @Multicast var socketSubscription: SocketSubscription

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
        phoenixSocket = Socket(socketURL, params: socketProperties)
        guard let phoenixSocket = phoenixSocket else { return }

        // Setup delegates for socket events
        phoenixSocket.delegateOnOpen(to: self) { (self) in
            self.logger.info("🚀 SOCKET opened\n")
            self.didTryToOpenSocketChannel = true
        }

        phoenixSocket.delegateOnClose(to: self) { (self) in
            self.logger.error("🛑 SOCKET closed\n")
            self.didTryToOpenSocketChannel = true
            self.$socketSubscription.invoke { $0.onSocketClosed() }
        }

        phoenixSocket.delegateOnError(to: self) { (self, error) in
            let (error, _) = error
            self.logger.error("🛑 SOCKET error - details %{public}@\n", error.localizedDescription)
            self.didTryToOpenSocketChannel = true
            self.closeSocket()
        }

        // Setup socket logger
        phoenixSocket.logger = { [weak self] message in
            self?.logger.debug("💡 SOCKET logger - message %{public}@\n", message)
        }

        // Setup the channel
        let channel = phoenixSocket.channel(SocketManager.channelTopic, params: socketChannelProperties)

        // Connect to the channel
        phoenixChannel = channel
        phoenixChannel?.join()
            .delegateReceive(SocketManager.successKey, to: self, callback: { (self, _) in
                self.logger.info("🚀 SOCKET channel JOINED\n")
                self.didTryToOpenSocketChannel = true
                self.$socketSubscription.invoke { $0.onSocketOpened() }
            })
            .delegateReceive(SocketManager.errorKey, to: self, callback: { (self, message) in
                self.logger.error("⚠️ SOCKET channel join FAIL: %{public}@\n", message.payload)
                self.didTryToOpenSocketChannel = true
                self.closeSocket()
            })

        // Connect the socket
        phoenixSocket.connect()
    }

    /**
     Closes the WebSocket connection and leaves the channel.
     
     - Parameter completion: A closure that is called when the disconnection completes.
     */
    private func closeSocket() {
        guard let phoenixSocket = phoenixSocket else { return }
        if let channel = self.phoenixChannel {
            channel.leave()
            phoenixSocket.remove(channel)
        }
        phoenixSocket.disconnect()
    }

}

// MARK: - SocketEvents

extension SocketManager: SocketEvents {

    /// Logic to determine if a new socket connection can be opened
    var isAllowToOpenSocket: Bool {
        !didTryToOpenSocketChannel && !isJoiningSocket && !isSocketOpened
    }

    /// Logic to determine if the channel state is joining
    var isJoiningSocket: Bool {
        phoenixChannel?.isJoining == true
    }

    /// Logic to check if the socket is currently open
    var isSocketOpened: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == true
    }

    // Implementation to allow open the WebSocket connection
    func allowToStart() {
        didTryToOpenSocketChannel = false
    }

    /// Implementation to open a WebSocket connection
    func connect() {
        openSocket()
    }

    /// Implementation to close the WebSocket connection
    func close() {
        closeSocket()
    }

    /// Implementation to publish an event over the WebSocket
    func publish(_ eventName: String, payload: [String: Any]?, shouldCloseSocket: Bool) {
        phoenixChannel?
            .push(eventName, payload: payload ?? [:])
            .receive(SocketManager.successKey) { [weak self] (_) in
                self?.logger.info("✈️ SOCKET message sent: %{public}@\n Payload: %{public}@", eventName, payload ?? [:])
                self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, true) }
                if shouldCloseSocket { self?.closeSocket() }
            }
            .receive(SocketManager.errorKey) { [weak self] (errorMessage) in
                self?.logger.error("⚠️ SOCKET message send FAIL: %{public}@", errorMessage.event)
                self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, false) }
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

    static var tokenKey: String { return "token" }
    static var userIDKey: String { return "user_id" }
    static var autoPropertiesKey: String { return "auto_properties" }
    static var appPropertiesKey: String { return "app_properties" }
    static var sdkVersionKey: String { return "sdk_version" }
}
