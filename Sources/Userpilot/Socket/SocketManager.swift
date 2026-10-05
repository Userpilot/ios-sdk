//
//  SocketManager.swift
//  Userpilot SDK
//
//  Created by Userpilot on 03/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for SocketManaging in `Userpilot.initializeContainer()`.
//  Main owns each connection from settings lookup through teardown.
//  See .agents/features/socket-v2-design.md for callback ordering and deliberate behavior changes.
//
//
//  Keep the service contract and implementation together, like the publishers.
//

// swiftlint:disable file_length
import Foundation

/// Lifecycle and publishing contract implemented by `SocketManager`.
internal protocol SocketManaging: AnyObject {

    /// True once the channel has joined and pushes can be sent.
    var isSocketOpened: Bool { get }

    /// True while a connection attempt is still being established.
    var isJoiningSocket: Bool { get }

    /// True when the last connection ended with an error rather than an intentional close.
    var didCloseFromError: Bool { get }

    /// True while a local close is tearing the connection down.
    var isShutdownState: Bool { get }

    /// Starts a connection attempt when none is open or in progress.
    func connect()

    /// Closes the current connection or cancels the attempt in progress.
    func close()

    /// Completes after local detachment, including when the socket was already idle.
    func close(completion: @escaping () -> Void)

    /// Publishes an event with its payload; the result is reported to subscribers.
    func publish(
        _ eventName: String,
        payload: Payload
    )

    /// Binds delivery to the submitting user and completes this specific push.
    /// Checks cancellation immediately before submission and again before delivering a result.
    func publish(
        _ eventName: String, payload: Payload, userID: String?,
        shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    )

    /// Registers a weakly held subscriber for socket lifecycle and push results.
    func registerCallback(_ socketSubscription: SocketSubscription)
}

/// Owns one connection attempt from settings lookup through local teardown.
/// Commands and callbacks enqueue on main; synchronous queries read one atomic snapshot.
/// Phoenix objects never cross that boundary. Analytics still owns delivery ordering.
internal final class SocketManager: SocketManaging {

    typealias SocketFactory = (_ endpoint: String, _ params: SwiftPhoenixClientPayload?) -> Socket

    /// Failed connections stay distinguishable after their Phoenix objects have been released.
    private enum Phase {
        case idle, fetchingSettings, joining, open, closing, failed
    }

    /// Main owns these fields. Closures capture only id, so they cannot retain the transport.
    private final class Connection {
        let id = UUID()
        let userID: String
        let token: String
        var socket: Socket?
        var channel: Channel?
        var pendingPushes = Set<UUID>()

        init(userID: String, token: String) {
            self.userID = userID
            self.token = token
        }
    }

    private weak var container: DIContainer?
    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let storage: DataStoring
    private let autoProperties: AutoPropertyDecoratoring
    private let remote: UserpilotRemoteSourcing
    private let logger: Logging
    private let socketFactory: SocketFactory
    private let subscribers = MulticastDelegate<SocketSubscription>()

    // Resolve this cycle only when delivering a response, after DI registration is complete.
    private var sessionMonitor: SessionMonitoring? { container?.resolve(SessionMonitoring.self) }

    // Only main accesses current; other queues read lifecycle and destination identity from this snapshot.
    private struct ReadState {
        var phase = Phase.idle
        var connectionID: UUID?
        var userID: String?
    }
    private let reads = AtomicReference(ReadState())
    private var phase: Phase {
        get { reads.value.phase }
        set {
            reads.value = ReadState(phase: newValue, connectionID: current?.id, userID: current?.userID)
        }
    }
    private var current: Connection?

    /// Replaces V1 in the SocketManaging registration. Construction starts no work.
    init(
        container: DIContainer,
        socketFactory: @escaping SocketFactory = { endpoint, params in Socket(endpoint, params: params) }
    ) {
        let config = container.resolve(Userpilot.Config.self)
        self.container = container
        self.userpilot = container.owner
        self.config = config
        self.storage = container.resolve(DataStoring.self)
        self.autoProperties = container.resolve(AutoPropertyDecoratoring.self)
        self.remote = container.resolve(UserpilotRemoteSourcing.self)
        self.logger = config.logger
        self.socketFactory = socketFactory
    }

    deinit {
        // Final release may occur off main. Retain only the abandoned connection for cleanup.
        guard let connection = current else { return }
        performOn(.main) { Self.dispose(connection) }
    }

    // MARK: - Any-thread API

    var isSocketOpened: Bool { phase == .open }

    /// Includes settings lookup: it is already an owned, cancellable connection attempt.
    var isJoiningSocket: Bool {
        let value = phase
        return value == .fetchingSettings || value == .joining
    }

    var didCloseFromError: Bool { phase == .failed }
    var isShutdownState: Bool { phase == .closing }

    /// Admission is checked on main, together with reserving the connection attempt.
    func connect() {
        onMain { $0.beginConnection() }
    }

    func close() { close(completion: {}) }

    /// Calls completion on main after local teardown, including when the manager is already idle.
    func close(completion: @escaping () -> Void) {
        onMain { manager in
            if let connection = manager.current {
                manager.finishConnection(connection, failed: false)
            }
            completion()
        }
    }

    /// Always enqueues, even on main, preserving publish → publish → close ordering.
    func publish(_ eventName: String, payload: Payload) {
        publish(eventName, payload: payload, userID: nil, shouldSend: { true }, completion: nil)
    }

    /// Bind this queued send to its submitted connection; a replacement cannot become its destination.
    func publish(
        _ eventName: String, payload: Payload, userID: String?,
        shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    ) {
        let state = reads.value
        let destination = userID == nil || userID == state.userID ? state.connectionID : nil
        onMain { $0.send(eventName, payload: payload, destination: destination,
                        shouldSend: shouldSend, completion: completion) }
    }

    /// The multicast owns its lock and weak references; registration does not wait on main.
    func registerCallback(_ socketSubscription: SocketSubscription) {
        subscribers.add(socketSubscription)
    }

    // MARK: - Ownership boundary

    /// Callback processing also enqueues, avoiding teardown inside Phoenix's callback iteration.
    private func onMain(_ action: @escaping (SocketManager) -> Void) {
        performOn(.main) { [weak self] in
            guard let self else { return }
            tryCatch { action(self) }
        }
    }

    /// Validate ownership once on entry: a closed connection can still deliver callbacks after its replacement opens.
    private func receive(_ id: UUID, _ action: @escaping (SocketManager, Connection) -> Void) {
        onMain { manager in
            guard let connection = manager.current, connection.id == id else { return }
            action(manager, connection)
        }
    }

    private static func assertOnMain() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }

    /// Validate admission and inbound callbacks against the selected identity. Outbound sends bind their destination.
    private func matchesIdentity(_ connection: Connection) -> Bool {
        storage.userId == connection.userID && config.token == connection.token
    }

    // MARK: - Settings and connection admission

    /// Reserve current before starting settings, so another connect cannot create a second attempt.
    private func beginConnection() {
        Self.assertOnMain()
        guard current == nil, config.token.isNotEmpty, storage.userId.isNotEmpty else { return }
        let connection = Connection(userID: storage.userId, token: config.token)
        current = connection
        phase = .fetchingSettings
        let id = connection.id
        logger.debug("🚥 Socket connection is establishing...")
        remote.fetchSettings { [weak self] result in
            self?.receive(id) { $0.didFetchSettings(result, connection: $1) }
        }
    }

    /// Continue only the settings phase for the selected user; receive has already checked connection ownership.
    private func didFetchSettings(_ result: Result<Void, RemoteSourceError>, connection: Connection) {
        Self.assertOnMain()
        guard phase == .fetchingSettings else { return }
        guard matchesIdentity(connection) else {
            logger.debug("Socket settings result discarded after identity changed")
            finishConnection(connection, failed: false)
            return
        }
        switch result {
        case .success:
            openConnection(connection)
        case .failure(let error):
            logger.error(
                "❗ Failed to fetch SDK settings: %{public}@, socket connection aborted",
                error.localizedDescription)
            finishConnection(connection, failed: true)
        }
    }

    /// Creates exactly one socket/channel pair. The channel's join timeout covers initial opening.
    private func openConnection(_ connection: Connection) {
        Self.assertOnMain()
        guard storage.socketURL.isNotEmpty,
              let deviceJSON = autoProperties.autoProperties.toJSONString(),
              let appJSON = autoProperties.appProperties.toJSONString() else {
            logger.error("Socket connection parameters are unavailable")
            finishConnection(connection, failed: true)
            return
        }
        let parameters: SwiftPhoenixClientPayload = [
            Constants.Socket.tokenKey: Environment.getClientToken(config: config),
            Constants.Socket.userIdKey: connection.userID,
            Constants.Socket.sdkVersionKey: userpilot?.version() ?? "",
            Constants.Socket.autoPropertiesKey: deviceJSON,
            Constants.Socket.appPropertiesKey: appJSON
        ]
        let socket = socketFactory(Environment.getSocketURL(storage: storage), parameters)
        let channel = socket.channel(Constants.Socket.channelTopic)
        connection.socket = socket
        connection.channel = channel
        phase = .joining
        observe(socket, channel: channel, id: connection.id)
        guard let join = channel.join() else {
            finishConnection(connection, failed: true)
            return
        }
        observeJoin(join, id: connection.id)
        socket.connect()
    }

    // MARK: - Phoenix callbacks

    /// Log lifecycle metadata only; Phoenix wire logs contain user payloads.
    private func observe(_ socket: Socket, channel: Channel, id: UUID) {
        Self.assertOnMain()
        socket.onOpen { [weak self] in
            self?.receive(id) { manager, _ in manager.logger.info("✅ SOCKET opened") }
        }
        socket.onClose { [weak self] in
            self?.receive(id) { manager, connection in
                manager.logger.error("🛑 SOCKET closed")
                manager.finishConnection(connection, failed: true)
            }
        }
        socket.onError { [weak self] error, _ in
            self?.receive(id) { manager, connection in
                manager.logger.error("❗ SOCKET error - details %{public}@", error.localizedDescription)
                manager.finishConnection(connection, failed: true)
            }
        }
        socket.onMessage { [weak self] message in
            self?.receive(id) { manager, connection in
                guard !message.isInvalidMessage,
                      manager.matchesIdentity(connection) else { return }
                manager.subscribers.invoke { $0.onNewMessage(message) }
            }
        }
        channel.onError { [weak self] _ in
            self?.receive(id) { manager, connection in
                manager.logger.error("❗ SOCKET Channel error")
                manager.finishConnection(connection, failed: true)
            }
        }
        channel.onClose { [weak self] _ in
            self?.receive(id) { manager, connection in
                manager.logger.debug("🛑 SOCKET Channel close")
                manager.finishConnection(connection, failed: true)
            }
        }
    }

    /// Only a successful channel join makes the manager open, not transport-open alone.
    private func observeJoin(_ push: Push, id: UUID) {
        Self.assertOnMain()
        push.receive(Constants.Socket.successKey) { [weak self] _ in
            self?.receive(id) { $0.didJoin($1) }
        }
        push.receive(Constants.Socket.errorKey) { [weak self] _ in
            self?.receive(id) { manager, connection in
                manager.logger.error("⚠️ SOCKET channel join failed")
                manager.finishConnection(connection, failed: true)
            }
        }
        push.receive(Constants.Socket.timeoutKey) { [weak self] _ in
            self?.receive(id) { manager, connection in
                manager.logger.error("⏱️ SOCKET channel join timed out")
                manager.finishConnection(connection, failed: true)
            }
        }
    }

    /// Recheck live Phoenix state: another transport callback may have arrived before this turn.
    private func didJoin(_ connection: Connection) {
        Self.assertOnMain()
        guard phase == .joining else { return }
        guard matchesIdentity(connection) else {
            finishConnection(connection, failed: false)
            return
        }
        guard connection.socket?.isConnected == true, connection.channel?.isJoined == true else { return }
        phase = .open
        logger.info("🚀 SOCKET channel joined")
        subscribers.invoke { $0.onSocketOpened() }
    }

}

// MARK: - Teardown and sending

extension SocketManager {

    /// Invalidate first, dispose second, notify last. Duplicate failure/close callbacks become inert.
    /// Completion means local transport detachment, not a server acknowledgement of channel leave.
    private func finishConnection(_ connection: Connection, failed: Bool) {
        Self.assertOnMain()
        phase = .closing
        current = nil
        Self.dispose(connection)
        phase = failed ? .failed : .idle
        if failed {
            logger.error("Socket connection ended with an error")
        } else {
            logger.debug("Socket connection closed")
        }
        subscribers.invoke { $0.onSocketClosed() }
    }

    /// Synchronous local teardown in this vendored Phoenix version; callbacks are quarantined first.
    private static func dispose(_ connection: Connection) {
        assertOnMain()
        connection.pendingPushes.removeAll()
        connection.socket?.releaseCallbacks()
        if let channel = connection.channel {
            if channel.canPush && !channel.isClosed { channel.leave() }
            connection.socket?.remove(channel)
        }
        connection.socket?.disconnect()
        connection.channel = nil
        connection.socket = nil
    }

    // MARK: - Push and resolution

    /// Recheck cancellation and joined readiness for the captured destination; no push means immediate failure.
    private func send(
        _ eventName: String, payload: Payload, destination: UUID?,
        shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    ) {
        Self.assertOnMain()
        guard shouldSend() else { return }
        guard let connection = current, connection.id == destination, phase == .open,
              let channel = connection.channel, channel.canPush,
              let push = channel.push(eventName, payload: payload ?? [:],
                                      timeout: Constants.Socket.pushTimeout) else {
            logger.error("Socket could not create push for event: %{public}@", eventName)
            let message = Message(topic: Constants.Socket.channelTopic, event: eventName,
                                  payload: ["status": Constants.Socket.errorKey])
            notifyEventSent(eventName, payload, message, false, completion)
            return
        }
        let id = connection.id
        let sendID = UUID()
        connection.pendingPushes.insert(sendID)
        for status in [Constants.Socket.successKey, Constants.Socket.errorKey, Constants.Socket.timeoutKey] {
            push.receive(status) { [weak self] message in
                self?.receive(id) { manager, connection in
                    guard connection.pendingPushes.remove(sendID) != nil,
                          manager.matchesIdentity(connection), shouldSend() else { return }
                    if status == Constants.Socket.timeoutKey {
                        manager.logger.error("⏱️ SOCKET push timed out for event: %{public}@", eventName)
                    }
                    manager.notifyEventSent(eventName, payload, message,
                                            status == Constants.Socket.successKey, completion)
                }
            }
        }
    }

    /// The sender owns completion; subscribers still receive shared screen-content and token replies.
    private func notifyEventSent(
        _ eventName: String, _ payload: Payload, _ message: Message,
        _ success: Bool, _ completion: SocketCompletion?
    ) {
        Self.assertOnMain()
        guard phase != .closing, sessionMonitor?.isAppActive == true else { return }
        tryCatch { completion?(message, success) }
        subscribers.invoke {
            $0.onSocketEventSent(message.resolvedEvent ?? eventName, payload, message, success)
        }
    }
}
