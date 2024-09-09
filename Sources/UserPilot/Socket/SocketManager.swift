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

    func publish(_ eventName: String, payload: [String: Any]?)
    func registerCallback(_ socketSubscription: SocketSubscription)
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
    private var didOpenSocketChannel: Bool = false

    /// Computed property for socket connection parameters.
    private var socketProperties: [String: String] {
        [
            SocketConstants.SOCKET_TOKEN_KEY: config.token,
            SocketConstants.SOCKET_USER_ID_KEY: storage.userID
        ]
    }

    /// Computed property for channel-specific parameters.
    private var socketChannelProperties: [String: Any] {
        [
            SocketConstants.SOCKET_TOKEN_KEY: config.token,
            SocketConstants.SOCKET_USER_ID_KEY: storage.userID,
            SocketConstants.SOCKET_SDK_VERSION_KEY: userPilot?.version() ?? "",
            SocketConstants.SOCKET_AUTO_PROPERTIES_KEY: autoPropertyDecorator.autoProperties,
            SocketConstants.SOCKET_APP_PROPERTIES_KEY: autoPropertyDecorator.appProperties
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
        }

        phoenixSocket.delegateOnClose(to: self) { (self) in
            self.logger.error("🛑 SOCKET closed\n")
            self.$socketSubscription.invoke { $0.onSocketClosed() }
        }

        phoenixSocket.delegateOnError(to: self) { (self, error) in
            let (error, _) = error
            self.logger.error("🛑 SOCKET error - details %{public}@\n", error.localizedDescription)
            self.closeSocket()
        }

        // Setup socket logger
        phoenixSocket.logger = { [weak self] message in
            self?.logger.debug("💡 SOCKET logger - message %{public}@\n", message)
        }

        // Setup the channel
        let channel = phoenixSocket.channel(SocketConstants.SOCKET_CHANNEL_TOPIC, params: socketChannelProperties)

        // Connect to the channel
        phoenixChannel = channel
        phoenixChannel?.join()
            .delegateReceive(SocketConstants.SOCKET_SUCCESS_KEY, to: self, callback: { (self, _) in
                self.didOpenSocketChannel = true
                self.logger.info("🚀 SOCKET channel JOINED\n")
                self.$socketSubscription.invoke { $0.onSocketOpened() }
            })
            .delegateReceive(SocketConstants.SOCKET_ERROR_KEY, to: self, callback: { (self, message) in
                self.logger.error("⚠️ SOCKET channel join FAIL: %{public}@\n", message.payload)
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
        !didOpenSocketChannel && phoenixChannel?.isJoining == false
    }

    /// Logic to determine if the channel state is joining
    var isJoiningSocket: Bool {
        phoenixChannel?.isJoining == true
    }

    /// Logic to check if the socket is currently open
    var isSocketOpened: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == true
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
    func publish(_ eventName: String, payload: [String: Any]?) {
        print("Socket Manager", eventName)
        $socketSubscription.invoke { $0.onSocketEventSent(eventName, true) }
//        phoenixChannel?
//            .push(eventName, payload: payload ?? [:])
//            .receive(SocketConstants.SOCKET_SUCCESS_KEY) { [weak self] (_) in
//                self?.logger.info("✈️ SOCKET message sent: %{public}@\n Payload: %{public}@", eventName, payload ?? [:])
//                self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, true) }
//            }
//            .receive(SocketConstants.SOCKET_ERROR_KEY) { [weak self] (errorMessage) in
//                self?.logger.error("⚠️ SOCKET message send FAIL: %{public}@", errorMessage.event)
//                self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, false) }
//            }
    }

    /// Implementation to register a callback for socket events
    func registerCallback(_ socketSubscription: SocketSubscription) {
        self.socketSubscription = socketSubscription
    }
}
