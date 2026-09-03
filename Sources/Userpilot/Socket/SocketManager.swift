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
 `SocketManaging` defines methods and properties for managing WebSocket connections and events.
 */
// swiftlint:disable file_length
internal protocol SocketManaging: AnyObject {
    /// Read-only socket state, derived from the Phoenix socket/channel objects.
    /// These are routing queries for consumers; all state MANAGEMENT (open/close
    /// gating, half-open recovery, callback suppression) is internal to the manager.
    var isSocketOpened: Bool { get }
    var isJoiningSocket: Bool { get }
    var didCloseFromError: Bool { get }
    var isShutdownState: Bool { get }

    /// Handle socket open & close. `connect()` is always safe to call — it gates
    /// itself on the current socket state and recovers a half-open transport.
    func connect()
    func close()

    /// Publish socket events. Push resolutions are delivered to all registered
    /// subscribers with `message.resolvedEvent` (the response `request_type`) as
    /// the event name, so no per-call subscription is needed — consumers filter
    /// by event name. Resolutions are suppressed internally during teardown or
    /// while the app is inactive.
    func publish(
        _ eventName: String,
        payload: Payload
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
internal class SocketManager {

    // MARK: - Properties

    typealias SocketFactory = (_ endpoint: String, _ params: SwiftPhoenixClientPayload?) -> Socket

    /// Guards `storedPhoenixSocket` / `storedPhoenixChannel`.
    ///
    /// Both are replaced on the main queue by `createAndConnectSocket()` while the state getters
    /// read them from other queues (the analytics watchdog, the experience queue). As plain stored
    /// properties that was a load-then-retain race: the reader loads the pointer, the writer
    /// releases the last reference, and the reader dereferences freed memory. Reading under the lock
    /// hands the caller its own strong reference for the duration of the access.
    ///
    /// The setters hand the replaced value out of the critical section before releasing it:
    /// `NSLock` is not recursive, so a `deinit` running under the lock that reached back into
    /// either accessor would deadlock instead of crashing.
    private let phoenixLock = NSLock()

    private var storedPhoenixSocket: Socket?

    private var storedPhoenixChannel: Channel?

    /// The WebSocket instance for handling connections.
    private var phoenixSocket: Socket? {
        get {
            phoenixLock.lock()
            defer { phoenixLock.unlock() }
            return storedPhoenixSocket
        }
        set {
            phoenixLock.lock()
            let previous = storedPhoenixSocket
            storedPhoenixSocket = newValue
            phoenixLock.unlock()
            // Released here, with the lock already dropped.
            _ = previous
        }
    }

    /// The channel within the WebSocket connection.
    private var phoenixChannel: Channel? {
        get {
            phoenixLock.lock()
            defer { phoenixLock.unlock() }
            return storedPhoenixChannel
        }
        set {
            phoenixLock.lock()
            let previous = storedPhoenixChannel
            storedPhoenixChannel = newValue
            phoenixLock.unlock()
            // Released here, with the lock already dropped.
            _ = previous
        }
    }

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

    /// True while an intentional close is in progress. Suppresses push callbacks that
    /// race the teardown; cleared when a new connection attempt starts.
    private var isClosingSocket = false

    /// Guards the socket state snapshot below.
    private let stateLock = NSLock()

    /// Mirrors `phoenixSocket.isConnected`.
    ///
    /// The Phoenix objects are only ever touched on the main queue, but socket state is read from
    /// any queue. These flags let those readers answer without dereferencing
    /// `phoenixSocket`/`phoenixChannel` while main is tearing them down, which used to crash in
    /// `PhoenixTransport.readyState`.
    private var socketConnected = false

    /// Mirrors `phoenixChannel?.isJoined`. `nil` until a channel exists.
    private var channelJoined: Bool?

    /// Mirrors `phoenixChannel.isJoining`.
    private var channelJoining = false

    // track fetching socket settings
    private lazy var isFetchingSocketSettings: AtomicReference<Bool> = AtomicReference(false)

    /// Factory used to create Phoenix sockets. Production uses the real transport;
    /// tests can inject a fake transport while still exercising the real manager.
    private let socketFactory: SocketFactory

    // MARK: - Initialization

    /**
     Initializes the `SocketManager` with dependencies provided by the `DIContainer`.

     - Parameter container: The dependency injection container.
     */
    init(
        container: DIContainer,
        socketFactory: @escaping SocketFactory = { endpoint, params in
            Socket(endpoint, params: params)
        }
    ) {
        self.container = container
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.userpilotRemoteSource = container.resolve(UserpilotRemoteSourcing.self)
        self.logger = config.logger
        self.socketFactory = socketFactory
    }

    /// DI container kept for use-time resolution of lifecycle state; resolving
    /// `SessionMonitoring` at init would create a dependency cycle.
    private weak var container: DIContainer?

    /// Session monitoring to know when the app is inactive (background teardown).
    private weak var sessionMonitorer: SessionMonitoring? {
        return container?.resolve(SessionMonitoring.self)
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
    /// Always hops to the main queue before touching Phoenix.
    ///
    /// Phoenix drives its reconnect timer and heartbeat on main, forwards every transport delegate
    /// callback to main, and `closeSocket()` hops to main - so main is the queue that already
    /// serializes its state machine. `fetchSettings` delivers its completion on the URLSession
    /// delegate queue, so without this hop `connect()` runs concurrently with
    /// `disconnect()`/`teardown()` and the socket is torn down mid-connect.
    private func openSocket() {
        performOn(.main) { [weak self] in
            guard let self else { return }
            // A teardown was requested while the settings request was in flight - do not reopen.
            // Release the single-flight gate too, or no later connect() could ever claim it.
            if self.isShutdownState {
                self.isFetchingSocketSettings.value = false
                return
            }
            self.createAndConnectSocket()
        }
    }

    // Creates the socket and channel and starts connecting.
    // Must only be called on the main queue.
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
            quarantinePreviousSocket()

            isClosingSocket = false

            let socketProperties: [String: Any] = [
                Constants.Socket.tokenKey: Environment.getClientToken(config: config),
                Constants.Socket.userIdKey: storage.userId,
                Constants.Socket.sdkVersionKey: userpilot?.version() ?? "",
                Constants.Socket.autoPropertiesKey: autoProperties,
                Constants.Socket.appPropertiesKey: appProperties
            ]
            phoenixSocket = socketFactory(
                Environment.getSocketURL(storage: storage),
                socketProperties
            )

            guard let phoenixSocket else {
                // No socket to dial - release the gate so a later attempt is not blocked forever.
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
                // Teardown finished — allow future connection attempts.
                self.isClosingSocket = false
                self.$socketSubscription.invoke { $0.onSocketClosed() }
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
            withStateLock {
                channelJoined = false
                channelJoining = true
            }
            phoenixChannel?.join()?
                .delegateReceive(
                    Constants.Socket.successKey, to: self,
                    callback: { (self, _) in
                        self.logger.info("🚀 SOCKET channel joined")
                        self.withStateLock {
                            self.channelJoined = true
                            self.channelJoining = false
                        }
                        self.$socketSubscription.invoke { $0.onSocketOpened() }
                        self.isFetchingSocketSettings.value = false
                    }
                )
                .delegateReceive(
                    Constants.Socket.errorKey, to: self,
                    callback: { (self, message) in
                        self.logger.error(
                            "⚠️ SOCKET channel join failed: %{public}@", message.payload)
                        self.closeSocket()
                        self.isFetchingSocketSettings.value = false
                    })
                .delegateReceive(
                    Constants.Socket.timeoutKey, to: self,
                    callback: { (self, _) in
                        // A silently timed-out join is the birth of the half-open
                        // state (socket connected, channel never joined) — kill it
                        // at the source; onSocketClosed drives normal recovery.
                        self.logger.error("⏱️ SOCKET channel join timed out")
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
    /// Structurally abandon any previous transport (e.g. a half-open socket whose
    /// channel never joined): quarantine its callbacks first so tearing it down
    /// cannot fire stale close/error events into subscribers, then disconnect it.
    /// Captures the instance locally and tears down synchronously — race-free
    /// against a replacement, and a no-op for an already-closed socket.
    /// Must only be called on the main queue - it tears the transport down.
    private func quarantinePreviousSocket() {
        guard let oldSocket = phoenixSocket else { return }
        if let oldChannel = phoenixChannel {
            oldSocket.remove(oldChannel)
        }
        oldSocket.releaseCallbacks()
        oldSocket.disconnect()
    }

    private func closeSocket() {
        // Only mark closing when there is a live socket to tear down; the flag is
        // cleared by `delegateOnClose` once the socket reports closed.
        if phoenixSocket != nil { isClosingSocket = true }
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

// MARK: - SocketManaging

extension SocketManager: SocketManaging {

    /// Logic to determine if the socket/channel is in a joining state
    var isJoiningSocket: Bool {
        phoenixSocket?.isConnecting == true || phoenixChannel?.isJoining == true
    }

    /// Logic to check if the socket is currently open
    var isSocketOpened: Bool {
        withStateLock { socketConnected && channelJoined == true }
    }

    /// Checks if the channel errored (used to prevent automatic reopen loops)
    var didCloseFromError: Bool {
        phoenixChannel?.isErrored == true
    }

    /// Checks if the socket is being intentionally torn down
    var isShutdownState: Bool {
        isClosingSocket
            || phoenixSocket?.connectionState == .closing
            || phoenixChannel?.isLeaving == true
    }

    /// Checks if a new connection attempt is currently allowed
    private var isAllowToOpenSocket: Bool {
        !isShutdownState && !isSocketOpened && !isJoiningSocket
    }

    /// Checks if the socket is currently opened without channel
    private var isSocketConnectedWithUnknownChannel: Bool {
        phoenixSocket?.isConnected == true && phoenixChannel?.isJoined == false
    }

    /// Implementation to open a WebSocket connection
    func connect() {
        if config.token.isEmpty || storage.userId.isEmpty || !isAllowToOpenSocket {
            return
        }
        // Half-open transport (connected, channel never joined) passes the gate
        // above — recover by abandoning it before dialing fresh. Hops to main: this tears the
        // transport down, so it must not run concurrently with the rest of the lifecycle.
        if isSocketConnectedWithUnknownChannel {
            performOn(.main) { [weak self] in
                self?.quarantinePreviousSocket()
            }
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

    /// Implementation to publish an event over the WebSocket
    ///
    /// Runs on the caller's queue - unlike the connect/teardown paths, which are all serialized on
    /// main. That is safe for the transport itself (`sendBuffer` is a `SynchronizedArray` and a send
    /// on a cancelled task just fails its completion), but `Socket.makeRef()` increments a plain
    /// `UInt64`, so a push racing the main-queue heartbeat can duplicate a message ref and misroute
    /// its ACK. Hopping to main would fix that; it would also reorder pushes relative to the caller,
    /// so it is left alone deliberately rather than by omission.
    func publish(
        _ eventName: String,
        payload: Payload
    ) {
        _ = tryCatch {
            phoenixChannel?
                .push(
                    eventName,
                    payload: payload ?? [:],
                    timeout: Constants.Socket.pushTimeout
                )?
                .receive(Constants.Socket.successKey) { [weak self] message in
                    self?.notifyEventSent(eventName, payload, message, true)
                }
                .receive(Constants.Socket.errorKey) { [weak self] message in
                    self?.notifyEventSent(eventName, payload, message, false)
                }
                .receive(Constants.Socket.timeoutKey) { [weak self] message in
                    // Without this hook a timed-out push resolves silently and the
                    // ACK-gated analytics queue stalls until the watchdog fires.
                    self?.logger.error("⏱️ SOCKET push timed out for event: %{public}@", eventName)
                    self?.notifyEventSent(eventName, payload, message, false)
                }
        }
    }

    /// Delivers a push resolution (ok/error/timeout) to all registered subscribers.
    /// The response's `request_type` identifies the event, so consumers filter by
    /// name; falls back to the pushed event name when the payload carries none
    /// (error/timeout resolutions). Suppressed during teardown or while the app is
    /// inactive (background flush) — resolutions must not re-drive the event queue
    /// mid-teardown.
    private func notifyEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ eventSent: Bool
    ) {
        guard !isShutdownState, sessionMonitorer?.isAppActive ?? false else { return }
        $socketSubscription.invoke {
            $0.onSocketEventSent(message.resolvedEvent ?? eventName, payload, message, eventSent)
        }
    }

    /// Implementation to register a callback for socket events
    func registerCallback(_ socketSubscription: SocketSubscription) {
        self.socketSubscription = socketSubscription
    }
}
