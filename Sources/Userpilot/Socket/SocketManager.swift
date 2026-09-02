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

/*
 `SocketEvents` defines methods and properties for managing WebSocket connections and events.
 */
// swiftlint:disable file_length
internal protocol SocketEvents: AnyObject {
    /// Return socket state
    var isSocketOpened: Bool { get }
    var isJoiningSocket: Bool { get }
    var didErrorOccurred: Bool { get }
    var isShutdownState: Bool { get }
    var isSocketConnectedWithUnknownChannel: Bool { get }

    /// Update socket state
    func updateSocketState(
        _ socketState: SocketManager.SocketState,
        forceUpdateState: Bool
    )

    /// Handle socket open & close
    func connect()
    func close()

    /// Publish socket events
    func publish(
        _ eventName: String,
        payload: Payload,
        socketSubscription: SocketSubscription?
    )

    /// Register socket subscription
    func registerCallback(_ socketSubscription: SocketSubscription)
}

extension SocketEvents {

    func publish(
        _ eventName: String,
        payload: Payload,
        socketSubscription: SocketSubscription? = nil
    ) {
        publish(
            eventName,
            payload: payload,
            socketSubscription: socketSubscription
        )
    }

    func updateSocketState(
        _ socketState: SocketManager.SocketState,
        forceUpdateState: Bool = false
    ) {
        updateSocketState(
            socketState,
            forceUpdateState: forceUpdateState
        )
    }
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
internal class SocketManager {

    // MARK: - Properties

    // Socket state enums
    enum SocketState {
        /**
         When application enter background state, the SDK flush events and then close socket
         without need to reopen.
         */
        case shuttingDown

        /**
         When SDK getting Identify event while it's already identified/opened channel.
         */
        case switchingUser

        /**
         When socket is opened.
         */
        case opened

        /**
         When socket closed.
         */
        case closed

        /**
         When socket channel is setup including getting settings and open the channel.
         */
        case connecting

        /**
         When getting socket channel error, to prevent retry.
         */
        case error
    }

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

    // track socket state - guarded by `stateLock`, always go through `socketState`
    private var socketStateValue: SocketState = .closed

    /// The current socket state. Both reading and writing take `stateLock`.
    ///
    /// Never touch this from inside a `withStateLock` block - use `socketStateValue` there instead,
    /// as `NSLock` is not recursive.
    private var socketState: SocketState {
        get { withStateLock { socketStateValue } }
        set { withStateLock { socketStateValue = newValue } }
    }

    /// Guards the socket state snapshot below.
    private let stateLock = NSLock()

    /// Mirrors `phoenixSocket.isConnected`.
    ///
    /// The Phoenix objects are only ever touched on the main queue, but socket state is read from
    /// any queue (the analytics flush reads it from a `ReadWriteLock` barrier). These flags let
    /// those readers answer without dereferencing `phoenixSocket`/`phoenixChannel` while main is
    /// tearing them down, which used to crash in `PhoenixTransport.readyState`.
    private var socketConnected = false

    /// Mirrors `phoenixChannel?.isJoined`. `nil` until a channel exists.
    private var channelJoined: Bool?

    /// Mirrors `phoenixChannel.isJoining`.
    private var channelJoining = false

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

    // MARK: - State snapshot

    /**
     Runs `body` while holding `stateLock`.

     Only read or assign the snapshot flags inside `body`; never call a socket API from it, as
     `NSLock` is not recursive.

     - Parameter body: The closure to execute under the lock.
     - Returns: The value returned by `body`.
     */
    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    /// Resets the socket state snapshot. Called when the socket is created and when it is closed.
    private func resetStateSnapshot() {
        withStateLock {
            socketConnected = false
            channelJoined = nil
            channelJoining = false
        }
    }

    /// Records that the channel is no longer joined nor joining, leaving the socket flag untouched.
    private func setChannelDetached() {
        withStateLock {
            channelJoined = false
            channelJoining = false
        }
    }

}

// MARK: - Socket Connection and Callbacks

extension SocketManager {

    /*
     Opens a WebSocket connection and joins the specified channel.

     Always hops to the main queue. Phoenix drives its reconnect timer and heartbeat on main,
     `closeSocket()` hops to main, and the transport forwards its delegate callbacks to main, so
     main is the queue that already serializes Phoenix lifecycle work. `fetchSettings` delivers its
     callback on the URLSession delegate queue, so without this hop `connect()` runs concurrently
     with `disconnect()`/`teardown()` and the socket is torn down mid-connect.
     */
    private func openSocket() {
        performOn(.main) { [weak self] in
            guard let self else { return }
            // A shutdown was requested while the settings request was in flight - do not reopen.
            // Release the single-flight gate too, or no later connect() could ever claim it.
            if self.socketState == .shuttingDown {
                self.isFetchingSocketSettings.value = false
                return
            }
            self.createAndConnectSocket()
        }
    }

    /*
     Creates the socket and channel and starts connecting. Must only be called on the main queue.
     */
    // swiftlint:disable:next function_body_length
    private func createAndConnectSocket() {
        guard
            storage.socketURL.isNotEmpty,
            config.token.isNotEmpty,
            storage.userId.isNotEmpty,
            let autoProperties = autoPropertyDecorator.autoProperties.toJSONString(),
            let appProperties = autoPropertyDecorator.appProperties.toJSONString()
        else {
            // Nothing to dial - release the gate so a later attempt is not blocked forever.
            isFetchingSocketSettings.value = false
            return
        }
        tryCatch {
            socketState = .connecting

            let socketProperties: [String: Any] = [
                SocketManager.tokenKey: Environment.getClientToken(config: config),
                SocketManager.userIdKey: storage.userId,
                SocketManager.sdkVersionKey: userpilot?.version() ?? "",
                SocketManager.autoPropertiesKey: autoProperties,
                SocketManager.appPropertiesKey: appProperties
            ]
            phoenixSocket = Socket(
                Environment.getSocketURL(storage: storage),
                params: socketProperties
            )

            guard let phoenixSocket else {
                socketState = .closed
                isFetchingSocketSettings.value = false
                return
            }

            resetStateSnapshot()

            // Setup delegates for socket events
            phoenixSocket.delegateOnOpen(to: self) { (self) in
                self.logger.info("✅ SOCKET opened")
                self.withStateLock { self.socketConnected = true }
            }

            phoenixSocket.delegateOnClose(to: self) { (self) in
                self.logger.error("🛑 SOCKET closed")
                self.withStateLock {
                    self.socketConnected = false
                    self.channelJoined = false
                    self.channelJoining = false
                }
                if self.socketState != .shuttingDown {
                    self.updateSocketState(.closed)
                    self.$socketSubscription.invoke { $0.onSocketClosed() }
                }
            }

            phoenixSocket.delegateOnError(to: self) { (self, error) in
                let (error, _) = error
                self.logger.error("❗ SOCKET error - details %{public}@", error.localizedDescription)
                self.updateSocketState(.error)
            }

            phoenixSocket.onMessage(callback: { [weak self] message in
                if message.isInvalidMessage { return }
                self?.$socketSubscription.invoke { $0.onNewMessage(message) }
            })

            phoenixSocket.logger = { [weak self] message in
                self?.logger.debug("✈️ SOCKET message: %{public}@", message)
            }

            // Setup the channel - always create a new channel instance to avoid join conflicts
            let channel = phoenixSocket.channel(SocketManager.channelTopic)

            // Connect to the channel
            phoenixChannel = channel
            withStateLock {
                channelJoined = false
                channelJoining = true
            }
            phoenixChannel?.join()?
                .delegateReceive(
                    SocketManager.successKey, to: self,
                    callback: { (self, _) in
                        self.logger.info("🚀 SOCKET channel joined")
                        self.withStateLock {
                            self.channelJoined = true
                            self.channelJoining = false
                        }
                        self.updateSocketState(.opened)
                        self.$socketSubscription.invoke { $0.onSocketOpened() }
                        self.isFetchingSocketSettings.value = false
                    }
                )
                .delegateReceive(
                    SocketManager.errorKey, to: self,
                    callback: { (self, message) in
                        self.logger.error(
                            "⚠️ SOCKET channel join failed: %{public}@", message.payload)
                        self.setChannelDetached()
                        self.updateSocketState(.error)
                        self.closeSocket()
                        self.isFetchingSocketSettings.value = false
                    })

            phoenixChannel?.onError { [weak self] message in
                self?.logger.error("❗ SOCKET Channel error: %{public}@", message.payload)
                self?.setChannelDetached()
                self?.updateSocketState(.error)
                self?.closeSocket()
                self?.isFetchingSocketSettings.value = false
            }

            phoenixChannel?.onClose { [weak self] message in
                self?.logger.debug("🛑 SOCKET Channel close: %{public}@", message.payload)
                self?.setChannelDetached()
                self?.updateSocketState(.closed)
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
            guard let self else { return }
            self.resetStateSnapshot()
            tryCatch {
                if let channel = self.phoenixChannel {
                    if channel.canPush && !channel.isClosed {
                        channel.leave()
                    }
                    self.phoenixSocket?.remove(channel)
                }
                self.phoenixSocket?.disconnect()
            }
            // Release both: `createAndConnectSocket()` always builds a fresh socket and channel, so
            // keeping the closed ones only held their transport alive and let `publish` push into a
            // dead channel's send buffer.
            self.phoenixChannel = nil
            self.phoenixSocket = nil
        }
    }

}

// MARK: - SocketEvents

extension SocketManager: SocketEvents {

    /// Logic to determine if the channel state is joining
    var isJoiningSocket: Bool {
        withStateLock { channelJoining || socketStateValue == .connecting }
    }

    /// Logic to check if the socket is currently open
    var isSocketOpened: Bool {
        withStateLock { socketConnected && channelJoined == true }
    }

    /// Checks if the socket is closed due to error reason
    var didErrorOccurred: Bool {
        socketState == .error
    }

    /// Checks if the socket in shutting down state
    var isShutdownState: Bool {
        socketState == .shuttingDown
    }

    /// Update socket state
    ///
    /// The read and the write happen in one locked step so two queues cannot both decide the
    /// transition is allowed and then clobber each other.
    func updateSocketState(
        _ newSocketState: SocketManager.SocketState,
        forceUpdateState: Bool = false
    ) {
        withStateLock {
            if forceUpdateState || newSocketState == .error {
                socketStateValue = newSocketState
                return
            }
            if socketStateValue == newSocketState || socketStateValue == .error { return }
            // Keep shuttingDown until a later connect() force-clears it; otherwise close()
            // and transport callbacks would reopen during teardown.
            if socketStateValue == .shuttingDown { return }
            socketStateValue = newSocketState
        }
    }

    /// Checks if the socket is currently opened without channel
    var isSocketConnectedWithUnknownChannel: Bool {
        withStateLock { socketConnected && channelJoined == false }
    }

    /// Implementation to open a WebSocket connection
    func connect() {
        if config.token.isEmpty || storage.userId.isEmpty || isSocketOpened || isJoiningSocket {
            return
        }
        // Resume/identify after flush or logout must be able to dial again.
        if isShutdownState {
            updateSocketState(.closed, forceUpdateState: true)
        }
        // `compareAndSet` is the single-flight gate: it supersedes the locked state claim the
        // hotfix added on main, since it already prevents two queues from both dialling.
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
        // Do not clobber shuttingDown: an in-flight fetchSettings callback checks that
        // marker in `openSocket()` and must not create a new socket during teardown.
        if socketState != .shuttingDown {
            updateSocketState(.closed)
        }
        closeSocket()
    }

    /// Implementation to publish an event over the WebSocket
    ///
    /// Hops to main like the rest of the socket lifecycle: pushing reads the socket's transport and
    /// mutates its internal message ref and send buffer, so it must not run concurrently with
    /// `closeSocket()`. Pushes stay in order because the main queue is FIFO. See `openSocket()`.
    func publish(
        _ eventName: String,
        payload: Payload,
        socketSubscription: SocketSubscription?
    ) {
        performOn(.main) { [weak self] in
            guard let self else { return }
            _ = tryCatch {
                self.phoenixChannel?
                    .push(eventName, payload: payload ?? [:])?
                    .receive(SocketManager.successKey) { [weak self] message in
                        if self?.socketState != .shuttingDown {
                            if let socketSubscription {
                                socketSubscription.onSocketEventSent(eventName, payload, message, true)
                            } else {
                                self?.$socketSubscription.invoke {
                                    $0.onSocketEventSent(eventName, payload, message, true)
                                }
                            }
                        }
                    }
                    .receive(SocketManager.errorKey) { [weak self] message in
                        if self?.socketState != .shuttingDown {
                            if let socketSubscription {
                                socketSubscription.onSocketEventSent(eventName, payload, message, false)
                            } else {
                                self?.$socketSubscription.invoke {
                                    $0.onSocketEventSent(eventName, payload, message, false)
                                }
                            }
                        }
                    }
            }
        }
    }

    /// Implementation to register a callback for socket events
    func registerCallback(_ socketSubscription: SocketSubscription) {
        self.socketSubscription = socketSubscription
    }
}

// MARK: - Properties name

extension SocketManager {

    // Static constants
    private static let channelTopic = "events:*"
    private static let successKey = "ok"
    private static let errorKey = "error"

    private static let tokenKey = "app_token"
    private static let userIdKey = "user_id"
    private static let autoPropertiesKey = "auto_properties"
    private static let appPropertiesKey = "app_properties"
    private static let sdkVersionKey = "sdk_version"
}
