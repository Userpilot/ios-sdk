//
//  SocketManagerV2.swift
//  Userpilot SDK
//
//  Created on 03/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for SocketManaging in `Userpilot.initializeContainer()` in place of
//  `SocketManager`, which stays in the target as the fallback.
//  Main owns each connection from settings lookup through teardown.
//  See .agents/features/socket-v2-design.md for callback ordering and deliberate behavior changes.
//

import Foundation

/// Implements the existing SocketManaging contract.
/// Commands and callbacks enqueue on main; synchronous queries read one atomic phase.
/// Phoenix objects never cross that boundary. Analytics still owns delivery ordering.
internal final class SocketManagerV2: SocketManaging {

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

    // Only main writes phase or accesses current. Other queues read the atomic phase only.
    private let phase = AtomicReference(Phase.idle)
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

    var isSocketOpened: Bool { phase.value == .open }

    /// Includes settings lookup: it is already an owned, cancellable connection attempt.
    var isJoiningSocket: Bool {
        let value = phase.value
        return value == .fetchingSettings || value == .joining
    }

    var didCloseFromError: Bool { phase.value == .failed }
    var isShutdownState: Bool { phase.value == .closing }

    /// Admission is checked on main, together with reserving the connection attempt.
    func connect() {
        onMain { $0.beginConnection() }
    }

    /// Cancels settings lookup logically, or tears down the owned transport. Idle close is a no-op.
    func close() {
        onMain { manager in
            guard let id = manager.current?.id else { return }
            manager.finishConnection(id, failed: false)
        }
    }

    /// Always enqueues, even on main. Calls made in order keep publish → publish → close ordering.
    func publish(_ eventName: String, payload: Payload) {
        onMain { $0.send(eventName, payload: payload) }
    }

    /// The multicast owns its lock and weak references; registration does not wait on main.
    func registerCallback(_ socketSubscription: SocketSubscription) {
        subscribers.add(socketSubscription)
    }

    // MARK: - Ownership boundary

    /// Callback processing also enqueues, avoiding teardown inside Phoenix's callback iteration.
    private func onMain(_ action: @escaping (SocketManagerV2) -> Void) {
        performOn(.main) { [weak self] in
            guard let self else { return }
            tryCatch { action(self) }
        }
    }

    /// A cancelled settings request, old transport callback, or old ACK cannot affect its successor.
    private func receive(_ id: UUID, _ action: @escaping (SocketManagerV2) -> Void) {
        onMain { manager in
            guard manager.current?.id == id else { return }
            action(manager)
        }
    }

    private static func assertOnMain() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }

    /// Identity is captured at admission, then checked before opening or using that connection.
    private func matchesIdentity(_ connection: Connection) -> Bool {
        storage.userId == connection.userID && config.token == connection.token
    }

    // MARK: - Settings and connection admission

    /// current owns both the single-flight gate and cancellation identity; no separate busy flag.
    private func beginConnection() {
        Self.assertOnMain()
        guard current == nil, config.token.isNotEmpty, storage.userId.isNotEmpty else { return }
        let connection = Connection(userID: storage.userId, token: config.token)
        current = connection
        phase.value = .fetchingSettings
        let id = connection.id
        logger.debug("🚥 Socket connection is establishing...")
        remote.fetchSettings { [weak self] result in
            self?.receive(id) { $0.didFetchSettings(result, id: id) }
        }
    }

    /// RemoteSource may complete immediately from cache or on its URLSession queue.
    private func didFetchSettings(_ result: Result<Void, RemoteSourceError>, id: UUID) {
        Self.assertOnMain()
        guard phase.value == .fetchingSettings, let connection = current else { return }
        guard matchesIdentity(connection) else {
            logger.debug("Socket settings result discarded after identity changed")
            finishConnection(id, failed: false)
            return
        }
        switch result {
        case .success:
            openConnection(connection)
        case .failure(let error):
            logger.error(
                "❗ Failed to fetch SDK settings: %{public}@, socket connection aborted",
                error.localizedDescription)
            finishConnection(id, failed: true)
        }
    }

    /// Creates exactly one socket/channel pair. The channel's join timeout covers initial opening.
    private func openConnection(_ connection: Connection) {
        Self.assertOnMain()
        guard storage.socketURL.isNotEmpty,
              let deviceJSON = autoProperties.autoProperties.toJSONString(),
              let appJSON = autoProperties.appProperties.toJSONString() else {
            logger.error("Socket connection parameters are unavailable")
            finishConnection(connection.id, failed: true)
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
        phase.value = .joining
        observe(socket, channel: channel, id: connection.id)
        guard let join = channel.join() else {
            finishConnection(connection.id, failed: true)
            return
        }
        observeJoin(join, id: connection.id)
        socket.connect()
    }

    // MARK: - Phoenix callbacks

    /// The raw Phoenix logger matches V1: it prints every push with its payload and every reply.
    /// That includes user properties, so it is for testing; AGENTS.md forbids logging PII.
    private func observe(_ socket: Socket, channel: Channel, id: UUID) {
        Self.assertOnMain()
        socket.logger = { [weak self] message in
            self?.logger.debug("✈️ SOCKET message: %{public}@", message)
        }
        socket.onOpen { [weak self] in
            self?.receive(id) { $0.logger.info("✅ SOCKET opened") }
        }
        socket.onClose { [weak self] in
            self?.receive(id) { manager in
                manager.logger.error("🛑 SOCKET closed")
                manager.finishConnection(id, failed: true)
            }
        }
        socket.onError { [weak self] error, _ in
            self?.receive(id) { manager in
                manager.logger.error("❗ SOCKET error - details %{public}@", error.localizedDescription)
                manager.finishConnection(id, failed: true)
            }
        }
        socket.onMessage { [weak self] message in
            self?.receive(id) { manager in
                guard !message.isInvalidMessage,
                      let connection = manager.current, manager.matchesIdentity(connection) else { return }
                manager.subscribers.invoke { $0.onNewMessage(message) }
            }
        }
        channel.onError { [weak self] message in
            self?.receive(id) { manager in
                manager.logger.error("❗ SOCKET Channel error: %{public}@", message.payload)
                manager.finishConnection(id, failed: true)
            }
        }
        channel.onClose { [weak self] message in
            self?.receive(id) { manager in
                manager.logger.debug("🛑 SOCKET Channel close: %{public}@", message.payload)
                manager.finishConnection(id, failed: true)
            }
        }
    }

    /// Only a successful channel join makes the manager open, not transport-open alone.
    private func observeJoin(_ push: Push, id: UUID) {
        Self.assertOnMain()
        push.receive(Constants.Socket.successKey) { [weak self] _ in
            self?.receive(id) { $0.didJoin(id) }
        }
        push.receive(Constants.Socket.errorKey) { [weak self] message in
            self?.receive(id) { manager in
                manager.logger.error("⚠️ SOCKET channel join failed: %{public}@", message.payload)
                manager.finishConnection(id, failed: true)
            }
        }
        push.receive(Constants.Socket.timeoutKey) { [weak self] _ in
            self?.receive(id) { manager in
                manager.logger.error("⏱️ SOCKET channel join timed out")
                manager.finishConnection(id, failed: true)
            }
        }
    }

    /// Recheck live Phoenix state: another transport callback may have arrived before this turn.
    private func didJoin(_ id: UUID) {
        Self.assertOnMain()
        guard phase.value == .joining, let connection = current else { return }
        guard matchesIdentity(connection) else {
            finishConnection(id, failed: false)
            return
        }
        guard connection.socket?.isConnected == true, connection.channel?.isJoined == true else { return }
        phase.value = .open
        logger.info("🚀 SOCKET channel joined")
        subscribers.invoke { $0.onSocketOpened() }
    }

}

// MARK: - Teardown and sending

extension SocketManagerV2 {

    /// Invalidate first, dispose second, notify last. Duplicate failure/close callbacks become inert.
    /// Completion means local transport detachment, not a server acknowledgement of channel leave.
    private func finishConnection(_ id: UUID, failed: Bool) {
        Self.assertOnMain()
        guard let connection = current, connection.id == id else { return }
        phase.value = .closing
        current = nil
        Self.dispose(connection)
        phase.value = failed ? .failed : .idle
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

    /// Phoenix may buffer a push after join() starts. Its existing timeout still resolves that push.
    private func send(_ eventName: String, payload: Payload) {
        Self.assertOnMain()
        guard let connection = current, matchesIdentity(connection),
              let channel = connection.channel, channel.joinedOnce,
              let push = channel.push(eventName, payload: payload ?? [:], timeout: Constants.Socket.pushTimeout) else {
            failSend(eventName, payload: payload)
            return
        }
        let id = connection.id
        let sendID = UUID()
        connection.pendingPushes.insert(sendID)
        for status in [Constants.Socket.successKey, Constants.Socket.errorKey, Constants.Socket.timeoutKey] {
            push.receive(status) { [weak self] message in
                self?.receive(id) { manager in
                    guard let connection = manager.current,
                          connection.pendingPushes.remove(sendID) != nil,
                          manager.matchesIdentity(connection) else { return }
                    if status == Constants.Socket.timeoutKey {
                        manager.logger.error("⏱️ SOCKET push timed out for event: %{public}@", eventName)
                    }
                    manager.notifyEventSent(eventName, payload, message, status == Constants.Socket.successKey)
                }
            }
        }
    }

    /// Without a Push, Phoenix cannot produce a timeout. Resolve failure so analytics can advance.
    private func failSend(_ eventName: String, payload: Payload) {
        Self.assertOnMain()
        logger.error("Socket could not create push for event: %{public}@", eventName)
        let message = Message(
            topic: Constants.Socket.channelTopic,
            event: eventName,
            payload: ["status": Constants.Socket.errorKey]
        )
        notifyEventSent(eventName, payload, message, false)
    }

    /// Preserve request_type routing and the original payload. Teardown cancels old pushes silently;
    /// background sends are best effort and their replies must not restart analytics progression.
    private func notifyEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ success: Bool) {
        Self.assertOnMain()
        guard phase.value != .closing, sessionMonitor?.isAppActive == true else { return }
        subscribers.invoke { $0.onSocketEventSent(message.resolvedEvent ?? eventName, payload, message, success) }
    }
}
