//
//  SocketRefTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

/// Guards the uniqueness of Phoenix message refs.
///
/// `Socket.makeRef()` is called from at least three queues in this SDK: event pushes run on the
/// caller's queue (`Push.send()`), heartbeats on `com.phoenix.socket.heartbeat`, and state-change
/// registrations wherever the caller happens to be. A duplicated ref means a reply can resolve the
/// wrong push — and because this SDK's analytics queue is ACK-gated, that either advances the queue
/// past an event that was never sent or stalls it behind one that will never resolve.
final class SocketRefTests: XCTestCase {

    private var socket: Socket!

    override func setUp() {
        super.setUp()
        // Never connected — `makeRef()` is pure counter arithmetic.
        socket = Socket("ws://localhost:4000/socket")
    }

    override func tearDown() {
        socket = nil
        super.tearDown()
    }

    /// Collects refs from many queues at once.
    private final class RefCollector {
        private let lock = NSLock()
        private var refs: [String] = []

        func append(_ ref: String) {
            lock.lock()
            refs.append(ref)
            lock.unlock()
        }

        var all: [String] {
            lock.lock()
            defer { lock.unlock() }
            return refs
        }
    }

    func testMakeRef_underConcurrentCallers_neverRepeatsARef() {
        let iterations = 5_000
        let collector = RefCollector()

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            collector.append(socket.makeRef())
        }

        let all = collector.all
        XCTAssertEqual(all.count, iterations)
        XCTAssertEqual(
            Set(all).count, iterations,
            "every push must get its own message ref, or replies resolve the wrong push")
    }

    /// The heartbeat is the concrete second caller: it runs on its own serial queue while pushes
    /// run on the caller's, which is exactly the interleaving that duplicated refs in production.
    func testMakeRef_pushesRacingTheHeartbeatQueue_stayUnique() {
        let iterations = 2_000
        let collector = RefCollector()
        let heartbeatQueue = Defaults.heartbeatQueue
        let group = DispatchGroup()

        for _ in 0..<iterations {
            group.enter()
            heartbeatQueue.async {
                collector.append(self.socket.makeRef())
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                collector.append(self.socket.makeRef())
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)

        let all = collector.all
        XCTAssertEqual(all.count, iterations * 2)
        XCTAssertEqual(
            Set(all).count, all.count,
            "a push racing the heartbeat must not share its ref")
    }

    /// The overflow wrap is the one piece of real logic in `makeRef()`; locking must not change it.
    func testMakeRef_wrapsAtOverflowWithoutRepeating() {
        socket.ref = UInt64.max - 1

        XCTAssertEqual(socket.makeRef(), String(UInt64.max))
        XCTAssertEqual(socket.makeRef(), "0")
        XCTAssertEqual(socket.makeRef(), "1")
    }
}
// swiftlint:enable all
