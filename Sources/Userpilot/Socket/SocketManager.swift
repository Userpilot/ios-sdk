//
//  SocketManager.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `SocketManager` handles socket events and state management for WebSocket connections.
//

import Foundation

// MARK: - Protocols

/// `SocketManaging` defines methods and properties for managing WebSocket connections and events.
internal protocol SocketManaging: AnyObject {
    /// Return socket state
    var isSocketOpened: Bool { get }
    var isJoiningSocket: Bool { get }
    var didCloseFromError: Bool { get }
    var isShutdownState: Bool { get }
    var isAllowToOpenSocket: Bool { get }
    var isSocketConnectedWithUnknownChannel: Bool { get }

    /// Handle socket open & close
    func connect()
    func close()

    /// Publish socket events
    func publish(
        _ eventName: String,
        payload: Payload,
        isClosingSocket: Bool
    )

    /// Register socket subscription
    func registerCallback(_ socketSubscription: SocketSubscription)
}

/// `SocketSubscription` defines a callback interface for handling socket event notifications.
internal protocol SocketSubscription: AnyObject {
    /// Listen to socket state
    func onSocketClosed()
    func onSocketOpened()
    func onSocketEventSent(
        _ event: String,
        _ payload: Payload,
        _ message: Message,
        _ status: Bool
    )

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

    func onSocketEventSent(
        _ event: String,
        _ payload: Payload,
        _ message: Message,
        _ status: Bool
    ) {
        // Default implementation (optional)
    }

    func onNewMessage(_ message: Message) {
        // Default implementation (optional)
    }
}

// MARK: - SocketManager

/// `SocketManager` is responsible for managing WebSocket connections, sending events, and handling responses.
internal class SocketManager: SocketManaging {

    // MARK: - Properties

    /// The WebSocket instance for handling connections.
    private var phoenixSocket: Socket?

    /// The channel within the WebSocket connection.
    private var phoenixChannel: Channel?

    /// SDK instance.
    private weak var userpilot: Userpilot?

    /// SDK Config.
    private let config: Userpilot.Config

    /// SDK storage.
    private let storage: DataStoring

    /// Auto property decorator.
    private let autoPropertyDecorator: AutoPropertyDecoratoring

    /// SDK logger
    private let logger: Logging

    /// SDK settings detector.
    private let userpilotRemoteSource: UserpilotRemoteSourcing

    /// socket susbcriber
    @Multicast var socketSubscription: SocketSubscription

    // track fetching socket settings
    private lazy var isFetchingSocketSettings: AtomicReference<Bool> = AtomicReference(false)

    // MARK: - Initialization

    /**
     Initializes the `SocketManager` with dependencies provided by the `DIContainer`.

     - Parameter container: The dependency injection container.
     */
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.userpilotRemoteSource = container.resolve(UserpilotRemoteSourcing.self)
        self.logger = config.logger
    }

}

// MARK: - SocketManaging
// Open socket
extension SocketManager {

    /// Implementation to open a WebSocket connection
    func connect() {
        if config.token.isEmpty || storage.userId.isEmpty || isSocketOpened || isJoiningSocket {
            return
        }
        if !isFetchingSocketSettings.compareAndSet(expected: false, new: true) {
            return
        }
        logger.debug("🚥 Socket connection is establishing...")
        userpilotRemoteSource.fetchSettings { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.openSocket()
            case .failure(let error):
                self.logger.error(
                    "❗ Failed to fetch SDK settings: %{public}@, socket connection aborted",
                    error.localizedDescription)
                self.isFetchingSocketSettings.value = false
            }
        }
    }

    /// Implementation to close the WebSocket connection
    func close() {
        closeSocket()
    }
}

// Handle connections
extension SocketManager {

    /*
     Opens a WebSocket connection and joins the specified channel.

     - Parameter completion: A closure that is called when the connection attempt completes.
     */
    // swiftlint:disable:next function_body_length
    private func openSocket() {
        guard
            storage.socketURL.isNotEmpty,
            config.token.isNotEmpty,
            storage.userId.isNotEmpty,
            let autoProperties = autoPropertyDecorator.autoProperties.toJSONString(),
            let appProperties = autoPropertyDecorator.appProperties.toJSONString()
        else { return }
        tryCatch {
            let socketProperties: [String: Any] = [
                Constants.Socket.tokenKey: Environment.getClientToken(config: config),
                Constants.Socket.userIdKey: storage.userId,
                Constants.Socket.sdkVersionKey: userpilot?.version() ?? "",
                Constants.Socket.autoPropertiesKey: autoProperties,
                Constants.Socket.appPropertiesKey: appProperties
            ]
            phoenixSocket = Socket(
                Environment.getSocketURL(storage: storage),
                params: socketProperties
            )

            guard let phoenixSocket else { return }

            // Setup delegates for socket events
            phoenixSocket.delegateOnOpen(to: self) { (self) in
                self.logger.info("✅ SOCKET opened")
            }

            phoenixSocket.delegateOnClose(to: self) { (self) in
                self.logger.error("🛑 SOCKET closed")
                if self.isShutdownState == false {
                    self.$socketSubscription.invoke { $0.onSocketClosed() }
                }
            }

            phoenixSocket.delegateOnError(to: self) { (self, error) in
                let (error, _) = error
                self.logger.error("❗ SOCKET error - details %{public}@", error.localizedDescription)
            }

            phoenixSocket.onMessage(callback: { [weak self] message in
                if message.isInvalidMessage { return }
                self?.$socketSubscription.invoke { $0.onNewMessage(message) }
            })

            phoenixSocket.logger = { [weak self] message in
                self?.logger.debug("✈️ SOCKET message: %{public}@", message)
            }

            // Setup the channel - always create a new channel instance to avoid join conflicts
            let channel = phoenixSocket.channel(Constants.Socket.channelTopic)

            // Connect to the channel
            phoenixChannel = channel
            phoenixChannel?.join()?
                .delegateReceive(
                    Constants.Socket.successKey, to: self,
                    callback: { (self, _) in
                        self.logger.info("🚀 SOCKET channel joined")
                        self.$socketSubscription.invoke { $0.onSocketOpened() }
                        self.isFetchingSocketSettings.value = false
                    }
                )
                .delegateReceive(
                    Constants.Socket.errorKey, to: self,
                    callback: { (self, message) in
                        self.logger.error("⚠️ SOCKET channel join failed: %{public}@", message.payload)
                        self.closeSocket()
                        self.isFetchingSocketSettings.value = false
                    })
            phoenixChannel?.onError { [weak self] message in
                self?.logger.error("❗ SOCKET Channel error: %{public}@", message.payload)
                self?.closeSocket()
                self?.isFetchingSocketSettings.value = false
            }

            phoenixChannel?.onClose { [weak self] message in
                self?.logger.debug("🛑 SOCKET Channel close: %{public}@", message.payload)
                self?.isFetchingSocketSettings.value = false
            }

            // Connect the socket
            phoenixSocket.connect()
        }
    }

    /**
     Closes the WebSocket connection and leaves the channel.

     - Parameter completion: A closure that is called when the disconnection completes.
     */
    private func closeSocket() {
        performOn(.main) { [weak self] in
            tryCatch {
                if let channel = self?.phoenixChannel, !channel.isClosed {
                    channel.leave(timeout: 0.0)
                    self?.phoenixSocket?.remove(channel)
                }
                self?.phoenixSocket?.disconnect()
            }
        }
    }

}

// Push events
extension SocketManager {

    /// Implementation to publish an event over the WebSocket
    func publish(_ eventName: String, payload: Payload, isClosingSocket: Bool) {
        _ = tryCatch {
            phoenixChannel?
                .push(eventName, payload: payload ?? [:])?
                .receive(Constants.Socket.successKey) { [weak self] message in
                    if self?.isShutdownState == false && !isClosingSocket {
                        self?.$socketSubscription.invoke {
                            $0.onSocketEventSent(message.resolvedEvent ?? eventName, payload, message, true)
                        }
                    }
                }
                .receive(Constants.Socket.errorKey) { [weak self] message in
                    if self?.isShutdownState == false && !isClosingSocket {
                        self?.$socketSubscription.invoke {
                            $0.onSocketEventSent(message.resolvedEvent ?? eventName, payload, message, false)
                        }
                    }
                }
        }
    }
}

/// Socket state
extension SocketManager {

    /// Logic to check if the socket is currently open
    var isSocketOpened: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == true
    }

    /// Logic to determine if the channel state is joining
    var isJoiningSocket: Bool {
        phoenixSocket?.isConnecting == true || phoenixChannel?.isJoining == true
    }

    /// Checks if the socket in shutting down state
    var isShutdownState: Bool {
        phoenixSocket?.connectionState == .closing || phoenixChannel?.isLeaving == true
    }

    /// Checks if the socket is currently opened without channel
    var isSocketConnectedWithUnknownChannel: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == false
    }

    /// Checks if the socket is closed due to error reason
    var didCloseFromError: Bool {
        phoenixChannel?.isErrored == true
    }

    /// Checks if the socket in shutting down state
    var isAllowToOpenSocket: Bool {
        !isShutdownState && !isSocketOpened && !isJoiningSocket
    }

    /// Implementation to register a callback for socket events
    func registerCallback(_ socketSubscription: SocketSubscription) {
        self.socketSubscription = socketSubscription
    }
}
