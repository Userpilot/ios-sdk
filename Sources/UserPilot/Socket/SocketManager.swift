//
//  SocketManager.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
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
    /// Return socket state
    var isSocketOpened: Bool { get }
    var isJoiningSocket: Bool { get }
    var didErrorOccurred: Bool { get }
    var isShutdownState: Bool { get }
    var isSocketConnectedWithUnknownChannel: Bool { get }

    /// Update socket state
    func updateSocketState(_ socketState: SocketManager.SocketState)

    /// Handle socket open & close
    func connect()
    func close()

    /// Publish socket events
    func publish(_ eventName: String,
                 payload: Payload,
                 shouldCloseSocket: Bool,
                 socketSubscription: SocketSubscription?)

    /// Register socket subscription
    func registerCallback(_ socketSubscription: SocketSubscription)
}

internal extension SocketEvents {

    func publish(_ eventName: String,
                 payload: Payload,
                 shouldCloseSocket: Bool = false,
                 socketSubscription: SocketSubscription? = nil) {
        publish(eventName, payload: payload, shouldCloseSocket: shouldCloseSocket,
                socketSubscription: socketSubscription)
    }
}

/**
 `SocketSubscription` defines a callback interface for handling socket event notifications.
 */
internal protocol SocketSubscription: AnyObject {
    /// Listen to socket state
    func onSocketClosed()
    func onSocketOpened()
    func onSocketEventSent(_ event: String,
                           _ payload: Payload,
                           _ message: Message,
                           _ status: Bool)

    /// Receive new socket message
    func onNewMessage(_ message: Message)
}

extension SocketSubscription {
    func onSocketClosed() {
        // Default implementation (optional)
    }

    func onSocketOpened() {
        // Default implementation (optional)
    }

    func onSocketEventSent(_ event: String,
                           _ payload: Payload,
                           _ message: Message,
                           _ status: Bool) {
        // Default implementation (optional)
    }

    func onNewMessage(_ message: Message) {
        // Default implementation (optional)
    }
}

// MARK: - SocketManager

/**
 `SocketManager` is responsible for managing WebSocket connections, sending events, and handling responses.
 */
internal class SocketManager {

    // MARK: - Properties

    // Socket state enums
    enum SocketState {
        case shuttingDown
        case switchingUser
        case opened
        case closed
        case connecting
    }

    /// URL for the WebSocket connection.
    private let socketURL = "wss://analytex-dev-nxtapp-9990.userpilot.io/mobile/v1/events/websocket"

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

    // track socket state
    private var socketState: SocketState = .closed

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

    /*
     Opens a WebSocket connection and joins the specified channel.
     
     - Parameter completion: A closure that is called when the connection attempt completes.
     */
    // swiftlint:disable:next function_body_length
    private func openSocket() {
        guard
            storage.userID.isNotEmpty,
            let autoProperties = autoPropertyDecorator.autoProperties.toJSONString(),
            let appProperties = autoPropertyDecorator.appProperties.toJSONString()
        else { return }
        socketState = .connecting

        let socketProperties: [String: Any] = [
            SocketManager.tokenKey: "NX-44d03690",
            SocketManager.userIDKey: storage.userID,
            SocketManager.sdkVersionKey: userPilot?.version() ?? "",
            SocketManager.autoPropertiesKey: autoProperties,
            SocketManager.appPropertiesKey: appProperties
        ]

        phoenixSocket = Socket(isDebugMode ? socketURL : storage.socketURL, params: socketProperties)
        guard let phoenixSocket = phoenixSocket else { return }

        // Setup delegates for socket events
        phoenixSocket.delegateOnOpen(to: self) { (self) in
            self.logger.info("✅ SOCKET opened")
        }

        phoenixSocket.delegateOnClose(to: self) { (self) in
            self.logger.error("🛑 SOCKET closed")
            if self.socketState != .shuttingDown {
                self.$socketSubscription.invoke { $0.onSocketClosed() }
            }
            // self.socketState = .closed
        }

        phoenixSocket.delegateOnError(to: self) { (self, error) in
            let (error, _) = error
            self.isErrorOccurred = true
            self.logger.error("❗ SOCKET error - details %{public}@", error.localizedDescription)
            self.closeSocket()
        }

//        phoenixSocket.onMessage(callback: { [weak self] message in
//            if message.isInvalidMessage { return }
//             // self?.$socketSubscription.invoke { $0.onNewMessage(message) }
//        })

        phoenixSocket.logger = { [weak self] message in
            self?.logger.debug("✈️ SOCKET message: %{public}@", message)
        }

        // Setup the channel
        let channel = phoenixSocket.channel(SocketManager.channelTopic)

        // Connect to the channel
        phoenixChannel = channel
        phoenixChannel?.join()
            .delegateReceive(SocketManager.successKey, to: self, callback: { (self, _) in
                self.logger.info("🚀 SOCKET channel joined")
                self.socketState = .opened
                self.$socketSubscription.invoke { $0.onSocketOpened() }
            })
            .delegateReceive(SocketManager.errorKey, to: self, callback: { (self, message) in
                self.isErrorOccurred = true
                self.logger.error("⚠️ SOCKET channel join failed: %{public}@", message.payload)
                self.closeSocket()
            })

        phoenixChannel?.onError { [weak self] message in
            self?.isErrorOccurred = true
            self?.logger.debug("❗ SOCKET Channel error: %{public}@", message.payload)
            self?.closeSocket()
        }

        phoenixChannel?.onClose { [weak self] message in
            self?.socketState = .closed
            self?.logger.debug("🛑 SOCKET Channel close: %{public}@", message.payload)
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
        // socketState = .closed
        if let channel = self.phoenixChannel, !channel.isClosed {
            channel.leave(timeout: 0.0)
            phoenixSocket?.remove(channel)
        }
        if let phoenixSocket = phoenixSocket, phoenixSocket.isConnected {
            phoenixSocket.disconnect()
        }
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

    /// Checks if the socket is closed due to error reason
    var didErrorOccurred: Bool {
        isErrorOccurred
    }

    /// Checks if the socket in shutting down state
    var isShutdownState: Bool {
        socketState == .shuttingDown
    }

    /// Update socket state
    func updateSocketState(_ socketState: SocketManager.SocketState) {
        self.socketState = socketState
    }

    /// Checks if the socket is currently opened without channel
    var isSocketConnectedWithUnknownChannel: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == false
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
                 payload: Payload,
                 shouldCloseSocket: Bool,
                 socketSubscription: SocketSubscription?) {
        phoenixChannel?
            .push(eventName, payload: payload ?? [:])
            .receive(SocketManager.successKey) { [weak self] message in
                if self?.socketState != .shuttingDown {
                    if let socketSubscription {
                        socketSubscription.onSocketEventSent(eventName, payload, message, true)
                    } else {
                        self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, payload, message, true)
                        }
                    }
                }
                if shouldCloseSocket { self?.closeSocket() }
            }
            .receive(SocketManager.errorKey) { [weak self] message in
                if self?.socketState != .shuttingDown {
                    if let socketSubscription {
                        socketSubscription.onSocketEventSent(eventName, payload, message, false)
                    } else {
                        self?.$socketSubscription.invoke { $0.onSocketEventSent(eventName, payload, message, false)
                        }
                    }
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
