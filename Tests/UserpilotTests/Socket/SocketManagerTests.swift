//
//  SocketManagerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
final class SocketManagerTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var socketManager: SocketManager!
    private var subscription: RecordingSocketSubscription!
    private var transports: [FakePhoenixTransport]!
    private var socketEndpoints: [String]!
    private var socketParams: [SwiftPhoenixClientPayload?]!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-test-token"))
        userpilot.storage.socketURL = "https://socket.example.com/mobile/v1/events/websocket"
        userpilot.storage.userId = "user-1"
        userpilot.sessionMonitor.isAppActive = true
        subscription = RecordingSocketSubscription()
        transports = []
        socketEndpoints = []
        socketParams = []
        socketManager = makeSocketManager()
    }

    override func tearDown() {
        socketManager?.close()
        socketManager = nil
        subscription = nil
        transports = nil
        socketEndpoints = nil
        socketParams = nil
        userpilot = nil
        super.tearDown()
    }

    func testInitialStateIsClosed() {
        XCTAssertFalse(socketManager.isSocketOpened)
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.didCloseFromError)
        XCTAssertFalse(socketManager.isShutdownState)
    }

    func testConnectWithEmptyTokenDoesNotFetchSettingsOrCreateSocket() {
        userpilot = MockUserpilot(config: Userpilot.Config(token: ""))
        userpilot.storage.socketURL = "https://socket.example.com/mobile/v1/events/websocket"
        userpilot.storage.userId = "user-1"
        userpilot.remoteSource.onFetchSettings = { _ in
            XCTFail("SocketManager should not fetch settings when token is empty")
        }
        socketManager = makeSocketManager()

        socketManager.connect()

        XCTAssertTrue(transports.isEmpty)
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testConnectWithEmptyUserIdDoesNotFetchSettingsOrCreateSocket() {
        userpilot.storage.userId = ""
        userpilot.remoteSource.onFetchSettings = { _ in
            XCTFail("SocketManager should not fetch settings when user id is empty")
        }
        socketManager = makeSocketManager()

        socketManager.connect()

        XCTAssertTrue(transports.isEmpty)
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testConnectFetchesSettingsOnlyOnceWhileFetchIsInFlight() {
        var fetchCount = 0
        var completions = [(Result<Void, RemoteSourceError>) -> Void]()
        userpilot.remoteSource.onFetchSettings = { completion in
            fetchCount += 1
            completions.append(completion)
        }
        socketManager = makeSocketManager()

        socketManager.connect()
        socketManager.connect()

        XCTAssertEqual(fetchCount, 1)
        XCTAssertTrue(transports.isEmpty)

        completions.first?(.success(()))

        XCTAssertEqual(transports.count, 1)
    }

    func testConnectAfterSettingsFailureCanRetry() {
        var fetchCount = 0
        userpilot.remoteSource.onFetchSettings = { completion in
            fetchCount += 1
            completion(.failure(.networkError("offline")))
        }
        socketManager = makeSocketManager()

        socketManager.connect()
        socketManager.connect()

        XCTAssertEqual(fetchCount, 2)
        XCTAssertTrue(transports.isEmpty)
    }

    func testSuccessfulJoinOpensSocketAndNotifiesSubscribers() throws {
        socketManager.registerCallback(subscription)

        let transport = try openAndJoinSocket()

        XCTAssertTrue(socketManager.isSocketOpened)
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertEqual(subscription.openCount, 1)
        XCTAssertEqual(transport.connectCallCount, 1)
        XCTAssertEqual(socketEndpoints.last, userpilot.storage.socketURL)
        XCTAssertEqual(socketParams.last??[Constants.Socket.tokenKey] as? String, "NX-test-token")
        XCTAssertEqual(socketParams.last??[Constants.Socket.userIdKey] as? String, "user-1")
        XCTAssertNotNil(socketParams.last??[Constants.Socket.autoPropertiesKey] as? String)
        XCTAssertNotNil(socketParams.last??[Constants.Socket.appPropertiesKey] as? String)
    }

    func testIncomingMessagesIgnoresInvalidAndPublishesValidMessages() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()

        transport.receive(
            topic: "phoenix",
            event: "server_event",
            payload: ["request_type": "ignored"]
        )
        XCTAssertTrue(subscription.messages.isEmpty)

        transport.receive(
            topic: Constants.Socket.channelTopic,
            event: "server_event",
            payload: ["request_type": "valid_message"]
        )

        XCTAssertEqual(subscription.messages.count, 1)
        XCTAssertEqual(subscription.messages.last?.event, "server_event")
        XCTAssertEqual(subscription.messages.last?.resolvedEvent, "valid_message")
    }

    func testPublishSuccessNotifiesSubscribersWithResolvedEvent() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()

        socketManager.publish("track", payload: ["metadata": ["name": "Button clicked"]])
        let push = try XCTUnwrap(transport.lastSentPush(event: "track"))

        transport.reply(
            to: push,
            status: Constants.Socket.successKey,
            response: ["request_type": "resolved_track"]
        )

        let sentEvent = try XCTUnwrap(subscription.sentEvents.last)
        XCTAssertEqual(sentEvent.event, "resolved_track")
        XCTAssertTrue(sentEvent.status)
        XCTAssertEqual(sentEvent.payload?["metadata"] as? [String: String], ["name": "Button clicked"])
        XCTAssertEqual(sentEvent.message.resolvedEvent, "resolved_track")
    }

    func testPublishErrorNotifiesSubscribersWithOriginalEventName() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()

        socketManager.publish("track", payload: ["metadata": ["name": "Button clicked"]])
        let push = try XCTUnwrap(transport.lastSentPush(event: "track"))

        transport.reply(to: push, status: Constants.Socket.errorKey)

        let sentEvent = try XCTUnwrap(subscription.sentEvents.last)
        XCTAssertEqual(sentEvent.event, "track")
        XCTAssertFalse(sentEvent.status)
    }

    func testPublishTimeoutNotifiesSubscribersWithFailure() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()

        socketManager.publish("track", payload: ["metadata": ["name": "Button clicked"]])
        let push = try XCTUnwrap(transport.lastSentPush(event: "track"))

        transport.reply(to: push, status: Constants.Socket.timeoutKey)

        let sentEvent = try XCTUnwrap(subscription.sentEvents.last)
        XCTAssertEqual(sentEvent.event, "track")
        XCTAssertFalse(sentEvent.status)
    }

    func testPublishResolutionIsSuppressedWhenAppIsInactive() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()
        userpilot.sessionMonitor.isAppActive = false

        socketManager.publish("track", payload: ["metadata": ["name": "Button clicked"]])
        let push = try XCTUnwrap(transport.lastSentPush(event: "track"))

        transport.reply(
            to: push,
            status: Constants.Socket.successKey,
            response: ["request_type": "resolved_track"]
        )

        XCTAssertTrue(subscription.sentEvents.isEmpty)
    }

    func testPublishResolutionIsSuppressedDuringShutdown() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()

        socketManager.publish("track", payload: ["metadata": ["name": "Button clicked"]])
        let push = try XCTUnwrap(transport.lastSentPush(event: "track"))

        socketManager.close()
        transport.reply(
            to: push,
            status: Constants.Socket.successKey,
            response: ["request_type": "resolved_track"]
        )

        XCTAssertTrue(subscription.sentEvents.isEmpty)
    }

    func testCloseDisconnectsTransportAndNotifiesSubscribers() throws {
        socketManager.registerCallback(subscription)
        let transport = try openAndJoinSocket()
        let expectation = expectation(description: "Socket closed")
        subscription.onClose = { expectation.fulfill() }

        socketManager.close()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(subscription.closeCount, 1)
        XCTAssertEqual(transport.disconnectCallCount, 1)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    private func makeSocketManager() -> SocketManager {
        return SocketManager(container: userpilot.container) { [weak self] endpoint, params in
            let transport = FakePhoenixTransport()
            self?.transports.append(transport)
            self?.socketEndpoints.append(endpoint)
            self?.socketParams.append(params)
            let socket = Socket(
                endPoint: endpoint,
                transport: { _ in transport },
                paramsClosure: { params }
            )
            socket.timeout = 60.0
            socket.heartbeatInterval = 60.0
            return socket
        }
    }

    private func openAndJoinSocket(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> FakePhoenixTransport {
        socketManager.connect()
        let transport = try XCTUnwrap(transports.last, file: file, line: line)
        transport.open()
        let joinPush = try XCTUnwrap(
            transport.lastSentPush(event: ChannelEvent.join),
            "Expected channel join push",
            file: file,
            line: line
        )
        transport.reply(to: joinPush, status: Constants.Socket.successKey)
        return transport
    }
}

private final class RecordingSocketSubscription: SocketSubscription {
    struct SentEvent {
        let event: String
        let payload: Payload
        let message: Message
        let status: Bool
    }

    var openCount = 0
    var closeCount = 0
    var sentEvents = [SentEvent]()
    var messages = [Message]()
    var onClose: (() -> Void)?

    func onSocketOpened() {
        openCount += 1
    }

    func onSocketClosed() {
        closeCount += 1
        onClose?()
    }

    func onSocketEventSent(
        _ event: String,
        _ payload: Payload,
        _ message: Message,
        _ status: Bool
    ) {
        sentEvents.append(SentEvent(
            event: event,
            payload: payload,
            message: message,
            status: status
        ))
    }

    func onNewMessage(_ message: Message) {
        messages.append(message)
    }
}

private final class FakePhoenixTransport: PhoenixTransport {
    private(set) var readyState: PhoenixTransportReadyState = .closed
    var delegate: PhoenixTransportDelegate?

    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var sentPushes = [SentPush]()

    func connect(with headers: [String: Any]) {
        connectCallCount += 1
        readyState = .connecting
    }

    func disconnect(code: Int, reason: String?) {
        disconnectCallCount += 1
        readyState = .closed
    }

    func send(data: Data) {
        guard
            let rawPush = try? JSONSerialization.jsonObject(with: data) as? [Any?],
            let push = SentPush(rawPush: rawPush)
        else { return }
        sentPushes.append(push)
    }

    func open() {
        readyState = .open
        delegate?.onOpen(response: nil)
    }

    func receive(
        joinRef: String? = nil,
        ref: String = "",
        topic: String,
        event: String,
        payload: SwiftPhoenixClientPayload
    ) {
        let message: [Any?] = [joinRef, ref, topic, event, payload]
        guard
            let data = try? JSONSerialization.data(withJSONObject: message),
            let rawMessage = String(data: data, encoding: .utf8)
        else { return }
        delegate?.onMessage(message: rawMessage)
    }

    func reply(
        to push: SentPush,
        status: String,
        response: SwiftPhoenixClientPayload = [:]
    ) {
        receive(
            joinRef: push.joinRef,
            ref: push.ref,
            topic: push.topic,
            event: ChannelEvent.reply,
            payload: [
                "status": status,
                "response": response
            ]
        )
    }

    func lastSentPush(event: String) -> SentPush? {
        return sentPushes.last { $0.event == event }
    }
}

private struct SentPush {
    let joinRef: String?
    let ref: String
    let topic: String
    let event: String
    let payload: SwiftPhoenixClientPayload

    init?(rawPush: [Any?]) {
        guard
            rawPush.count == 5,
            let ref = rawPush[1] as? String,
            let topic = rawPush[2] as? String,
            let event = rawPush[3] as? String,
            let payload = rawPush[4] as? SwiftPhoenixClientPayload
        else { return nil }

        self.joinRef = rawPush[0] as? String
        self.ref = ref
        self.topic = topic
        self.event = event
        self.payload = payload
    }
}
// swiftlint:enable all
