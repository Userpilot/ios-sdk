//
//  SocketManagerStressTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 07/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises repeated lifecycle commands and concurrent callers against the real
//  socket manager with a controlled transport. No backend connection is opened.
//

import XCTest
@testable import Userpilot

final class SocketManagerStressTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var manager: SocketManager!
    private var subscription: RecordingSocketSubscription!
    private var transports: [FakePhoenixTransport] = []
    private var sockets: [Socket] = []
    private let producerCount = 4
    private let rounds = 25

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-test-token"))
        userpilot.storage.userId = "stress-user"
        userpilot.storage.socketURL = "wss://socket.example.test/socket"
        userpilot.sessionMonitor.isAppActive = true
        subscription = RecordingSocketSubscription()
        manager = SocketManager(container: userpilot.container) { [weak self] endpoint, params in
            XCTAssertTrue(Thread.isMainThread, "Phoenix must remain on its iOS owner queue")
            // Check during creation, not just after the burst: overlapping transports are a failure.
            XCTAssertTrue(self?.transports.allSatisfy { $0.disconnectCallCount == 1 } == true)
            let transport = FakePhoenixTransport()
            let socket = Socket(endPoint: endpoint, transport: { _ in transport }, paramsClosure: { params })
            socket.timeout = 60
            socket.heartbeatInterval = 60
            self?.transports.append(transport)
            self?.sockets.append(socket)
            return socket
        }
        manager.registerCallback(subscription)
    }

    override func tearDown() {
        manager.close()
        drainOwner()
        XCTAssertTrue(transports.allSatisfy { $0.disconnectCallCount == 1 })
        manager = nil
        sockets.removeAll()
        transports.removeAll()
        subscription = nil
        userpilot = nil
        super.tearDown()
    }

    func testOrderedConnectCloseSequence_forRepeatedCycles() throws {
        for _ in 0..<rounds {
            manager.connect()
            manager.close()
            manager.connect()
            manager.close()
            manager.close()
            manager.close()
            manager.connect()
            drainOwner()
            try finishJoin()
            XCTAssertTrue(manager.isSocketOpened)
            closeAndCheckCompletion()
        }
        XCTAssertEqual(subscription.openCount, rounds)
        XCTAssertEqual(transports.count, rounds)
    }

    func testConcurrentConnect_forPendingSettingsKeepsOneAttempt() {
        var settings: [(Result<Void, RemoteSourceError>) -> Void] = []
        userpilot.remoteSource.onFetchSettings = { settings.append($0) }
        runConcurrentCallers { [manager] in manager?.connect() }
        XCTAssertEqual(settings.count, 1)
        XCTAssertTrue(transports.isEmpty)
        XCTAssertTrue(manager.isJoiningSocket)

        closeAndCheckCompletion()
        manager.connect()
        drainOwner()
        XCTAssertEqual(settings.count, 2)
        guard settings.count == 2 else { return }
        settings[0](.success(()))
        drainOwner()
        XCTAssertTrue(transports.isEmpty, "An abandoned fetch cannot open a transport")
        settings[1](.success(()))
        drainOwner()
        XCTAssertEqual(transports.count, 1)
    }

    func testConcurrentClose_forJoinedSocketCompletesEveryCallerOnce() throws {
        try open()
        let completions = expectation(description: "Every close completes, including redundant closes")
        completions.expectedFulfillmentCount = producerCount * rounds
        completions.assertForOverFulfill = true
        runConcurrentCallers { [manager] in
            manager?.close { completions.fulfill() }
        }
        wait(for: [completions], timeout: 5)
        XCTAssertEqual(subscription.closeCount, 1)
        XCTAssertEqual(transports.first?.disconnectCallCount, 1)
        XCTAssertFalse(manager.isSocketOpened)
        XCTAssertFalse(manager.isShutdownState)
    }

    func testConcurrentLifecycleChurn_forDifferentQueuesRecoversUsableSocket() throws {
        try open()
        let completions = expectation(description: "Both closes in every producer iteration complete")
        completions.expectedFulfillmentCount = producerCount * rounds * 2
        completions.assertForOverFulfill = true
        runConcurrentCallers { [manager] in
            manager?.connect()
            manager?.close { completions.fulfill() }
            manager?.close { completions.fulfill() }
            manager?.connect()
        }
        wait(for: [completions], timeout: 5)
        // Producer order is deliberately unspecified. Establish a final ordered boundary before asserting state.
        closeAndCheckCompletion()
        try open()
        try assertCurrentPushCompletes()
        XCTAssertTrue(manager.isSocketOpened)
        XCTAssertFalse(manager.didCloseFromError)
        XCTAssertTrue(transports.dropLast().allSatisfy { $0.disconnectCallCount == 1 })
    }

    func testLateCallbacks_forRepeatedReplacementCannotAffectCurrentSocket() throws {
        for _ in 0..<rounds {
            try open()
            let oldSocket = try XCTUnwrap(sockets.last)
            // Capture registered callbacks before teardown removes them, as if already in delivery.
            let oldCloses = oldSocket.stateChangeCallbacks.close.copy().map { $0.callback }
            let oldErrors = oldSocket.stateChangeCallbacks.error.copy().map { $0.callback }
            let oldJoin = try XCTUnwrap(oldSocket.channels.first?.joinPush)
            let oldJoinSuccess = try XCTUnwrap(oldJoin.receiveHooks[Constants.Socket.successKey]?.last)
            let oldJoinError = try XCTUnwrap(oldJoin.receiveHooks[Constants.Socket.errorKey]?.last)
            let oldTransport = try XCTUnwrap(transports.last)
            manager.publish("track", payload: ["index": 1])
            drainOwner()
            let oldPush = try XCTUnwrap(oldTransport.lastSentPush(event: "track"))
            closeAndCheckCompletion()
            try open()
            let closeCount = subscription.closeCount
            let replyCount = subscription.sentEvents.count

            runConcurrentCallers {
                oldCloses.forEach { $0.call((1000, nil)) }
                oldErrors.forEach { $0.call((NSError(domain: "stale", code: 1), nil)) }
                oldJoinSuccess.call(Message())
                oldJoinError.call(Message())
            }
            oldTransport.reply(to: oldPush, status: Constants.Socket.successKey)
            drainOwner()
            XCTAssertTrue(manager.isSocketOpened)
            XCTAssertFalse(manager.didCloseFromError)
            XCTAssertEqual(subscription.closeCount, closeCount)
            XCTAssertEqual(subscription.sentEvents.count, replyCount)
            try assertCurrentPushCompletes()
            closeAndCheckCompletion()
        }
    }

    func testReconnectFromCloseCompletion_forRepeatedCycles() throws {
        for _ in 0..<rounds {
            try open()
            let completed = expectation(description: "Reentrant reconnect submitted after teardown")
            manager.close { [weak self] in
                XCTAssertFalse(self?.manager.isSocketOpened ?? true)
                XCTAssertEqual(self?.transports.last?.disconnectCallCount, 1)
                self?.manager.connect()
                completed.fulfill()
            }
            wait(for: [completed], timeout: 5)
            drainOwner()
            try finishJoin()
            XCTAssertTrue(manager.isSocketOpened)
            closeAndCheckCompletion()
        }
    }

    func testConcurrentPublish_forOutOfOrderRepliesResolvesEachRequestOnce() throws {
        try open()
        let nextIndex = AtomicReference(0)
        let completed = expectation(description: "Each concurrent request resolves its own completion once")
        completed.expectedFulfillmentCount = producerCount * rounds
        completed.assertForOverFulfill = true
        runConcurrentCallers { [manager] in
            let index = nextIndex.update { $0 + 1 }
            manager?.publish("track", payload: ["index": index], shouldSend: { true }, completion: { message, _ in
                XCTAssertEqual(message.payload["index"] as? Int, index)
                completed.fulfill()
            })
        }
        let transport = try XCTUnwrap(transports.last)
        let pushes = transport.sentPushes.filter { $0.event == "track" }
        XCTAssertEqual(pushes.count, producerCount * rounds)
        XCTAssertEqual(Set(pushes.map(\.ref)).count, pushes.count)
        for push in pushes.reversed() {
            let index = try XCTUnwrap(push.payload["index"] as? Int)
            let status = index.isMultiple(of: 2) ? Constants.Socket.successKey : Constants.Socket.errorKey
            transport.reply(to: push, status: status, response: ["index": index])
            transport.reply(to: push, status: Constants.Socket.successKey, response: ["index": index])
        }
        wait(for: [completed], timeout: 5)
        drainOwner()
        XCTAssertEqual(subscription.sentEvents.count, pushes.count)
        XCTAssertEqual(subscription.sentEvents.filter(\.status).count, pushes.count / 2)
    }

    func testRepeatedFailureAndReconnect_forDuplicateTerminalCallbacks() throws {
        for _ in 0..<rounds {
            try open()
            let socket = try XCTUnwrap(sockets.last)
            let failures = socket.stateChangeCallbacks.error.copy().map { $0.callback }
            let before = subscription.closeCount
            runConcurrentCallers {
                failures.forEach { $0.call((NSError(domain: "transport", code: 1), nil)) }
            }
            XCTAssertTrue(manager.didCloseFromError)
            XCTAssertEqual(subscription.closeCount, before + 1)
            try open()
            XCTAssertFalse(manager.didCloseFromError)
            try assertCurrentPushCompletes()
            closeAndCheckCompletion()
        }
    }

}

// MARK: - Controlled lifecycle and callers

private extension SocketManagerStressTests {

    /// Real producer queues race admission; only their submissions finish before the owner is drained.
    func runConcurrentCallers(_ action: @escaping () -> Void) {
        let submitted = expectation(description: "All background callers submitted their commands")
        submitted.expectedFulfillmentCount = producerCount
        for index in 0..<producerCount {
            let count = rounds
            DispatchQueue(label: "socket.stress.producer.\(index)").async {
                for _ in 0..<count { action() }
                submitted.fulfill()
            }
        }
        wait(for: [submitted], timeout: 5)
        drainOwner()
    }

    /// Settings callbacks enqueue another owner turn. FIFO barriers drain both turns without sleeping.
    func drainOwner() {
        for _ in 0..<2 {
            let drained = expectation(description: "Socket owner turn drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 5)
        }
    }

    func open() throws {
        manager.connect()
        drainOwner()
        try finishJoin()
    }

    func finishJoin() throws {
        let transport = try XCTUnwrap(transports.last)
        transport.open()
        drainOwner()
        let join = try XCTUnwrap(transport.lastSentPush(event: ChannelEvent.join))
        transport.reply(to: join, status: Constants.Socket.successKey)
        drainOwner()
        XCTAssertTrue(manager.isSocketOpened)
    }

    func closeAndCheckCompletion() {
        let completed = expectation(description: "Local teardown finished")
        manager.close { [weak self] in
            XCTAssertFalse(self?.manager.isSocketOpened ?? true)
            XCTAssertFalse(self?.manager.isJoiningSocket ?? true)
            XCTAssertFalse(self?.manager.isShutdownState ?? true)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
        drainOwner()
    }

    /// The surviving connection must carry and acknowledge a real serialized push, not merely report OPEN.
    func assertCurrentPushCompletes() throws {
        let before = subscription.sentEvents.count
        manager.publish("track", payload: ["index": 1])
        drainOwner()
        let transport = try XCTUnwrap(transports.last)
        let push = try XCTUnwrap(transport.lastSentPush(event: "track"))
        transport.reply(to: push, status: Constants.Socket.successKey)
        drainOwner()
        XCTAssertEqual(subscription.sentEvents.count, before + 1)
        XCTAssertEqual(subscription.sentEvents.last?.status, true)
    }
}
