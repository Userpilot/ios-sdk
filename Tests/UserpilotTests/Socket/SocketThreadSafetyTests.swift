//
//  SocketThreadSafetyTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 09/02/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  These tests verify that the SwiftPhoenixClient Socket and URLSessionTransport
//  are free of data races when accessed from multiple threads concurrently.
//
//  IMPORTANT: Run these tests with Thread Sanitizer (TSan) enabled:
//    Product > Scheme > Edit Scheme > Run > Diagnostics > Thread Sanitizer ✓
//
//  TSan will flag any data race even if the test doesn't crash, making these
//  tests highly effective at catching concurrency bugs.

import XCTest
@testable import Userpilot

// swiftlint:disable:next type_body_length
final class SocketThreadSafetyTests: XCTestCase {

    // MARK: - Rapid Connect/Disconnect Stress Test

    /// Stress test: rapidly connect and disconnect the socket from multiple
    /// concurrent threads. connect() and disconnect() dispatch onto the socket's
    /// serial queue, so this tests the main public API thread-safety.
    func testRapidConcurrentConnectDisconnect_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "stress-test"]
        )
        // Set a logger to exercise the logItems code path (the original crash site)
        socket.logger = { _ in }

        let iterations = 50
        let group = DispatchGroup()

        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                socket.connect()
                // Random micro-delay to maximize thread interleaving
                usleep(UInt32.random(in: 50...2000))
                socket.disconnect()
                group.leave()
            }

            // Every 5th iteration also read state from another thread
            if index % 5 == 0 {
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    _ = socket.isConnected
                    _ = socket.isConnecting
                    _ = socket.connectionState
                    _ = socket.websocketProtocol
                    group.leave()
                }
            }
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }

    // MARK: - Simulated Transport Error Path (Realistic)

    /// Exercises the exact crash path: transport delegate callbacks arriving
    /// while the socket is being connected/disconnected. In production,
    /// URLSessionTransport dispatches all delegate callbacks onto socket.queue.
    /// This test simulates that realistic path.
    func testConcurrentTransportDelegateCallbacks_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "delegate-test"]
        )
        socket.logger = { _ in }

        let group = DispatchGroup()

        // Simulate transport error callbacks arriving on the socket's queue
        // (as URLSessionTransport.dispatchOnDelegateQueue does in production)
        for _ in 0..<50 {
            group.enter()
            socket.queue.async {
                let error = NSError(domain: "test", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Simulated connection error"
                ])
                socket.onError(error: error, response: nil)
                group.leave()
            }
        }

        // Simulate onOpen callbacks arriving on the queue
        for _ in 0..<10 {
            group.enter()
            socket.queue.async {
                socket.onOpen(response: nil)
                group.leave()
            }
        }

        // Simulate onClose callbacks arriving on the queue
        for _ in 0..<10 {
            group.enter()
            socket.queue.async {
                socket.onClose(code: 999, reason: "simulated abnormal close")
                group.leave()
            }
        }

        // Simulate onMessage callbacks arriving on the queue
        for _ in 0..<10 {
            group.enter()
            socket.queue.async {
                socket.onMessage(message: "[null,null,\"phoenix\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]")
                group.leave()
            }
        }

        // Simultaneously connect/disconnect from external threads
        // (these dispatch onto the same queue internally)
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                socket.connect()
                usleep(UInt32.random(in: 100...1000))
                socket.disconnect()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }

    // MARK: - Callback Registration Under Contention

    /// Verifies that registering and removing state-change callbacks
    /// (onOpen, onClose, onError, onMessage) while the socket is
    /// connecting/disconnecting does not cause a data race.
    /// These use SynchronizedArray internally for thread safety.
    func testConcurrentCallbackRegistration_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "callback-test"]
        )
        socket.logger = { _ in }

        let group = DispatchGroup()

        for _ in 0..<30 {
            // Register and remove onOpen callbacks from background threads
            group.enter()
            DispatchQueue.global().async {
                let ref = socket.onOpen { }
                usleep(UInt32.random(in: 100...1000))
                socket.off([ref])
                group.leave()
            }

            // Register and remove onError callbacks from background threads
            group.enter()
            DispatchQueue.global().async {
                let ref = socket.onError { _ in }
                usleep(UInt32.random(in: 100...1000))
                socket.off([ref])
                group.leave()
            }

            // Register and remove onClose callbacks from background threads
            group.enter()
            DispatchQueue.global().async {
                let ref = socket.onClose { }
                usleep(UInt32.random(in: 100...1000))
                socket.off([ref])
                group.leave()
            }

            // Register and remove onMessage callbacks from background threads
            group.enter()
            DispatchQueue.global().async {
                let ref = socket.onMessage { _ in }
                usleep(UInt32.random(in: 100...1000))
                socket.off([ref])
                group.leave()
            }
        }

        // Simultaneously connect/disconnect
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<10 {
                socket.connect()
                usleep(UInt32.random(in: 500...3000))
                socket.disconnect()
            }
            group.leave()
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }

    // MARK: - Channel Creation Under Contention

    /// Verifies that creating channels while the socket is
    /// connecting/disconnecting does not cause a data race on
    /// the _channels array or socket state.
    func testConcurrentChannelCreation_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "channel-test"]
        )
        socket.logger = { _ in }

        let group = DispatchGroup()

        // Create channels from multiple threads
        for index in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let channel = socket.channel("room:\(index)", params: ["user": "test"])
                usleep(UInt32.random(in: 100...2000))
                _ = channel.isClosed
                _ = channel.isJoined
                socket.remove(channel)
                group.leave()
            }
        }

        // Simultaneously connect/disconnect
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<5 {
                socket.connect()
                usleep(UInt32.random(in: 1000...5000))
                socket.disconnect()
            }
            group.leave()
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }

    // MARK: - MakeRef Thread Safety

    /// Verifies that makeRef() (which increments a UInt64 counter)
    /// does not crash when called from the socket's serial queue concurrently
    /// with connect/disconnect from external threads.
    func testMakeRefWithConcurrentConnectDisconnect_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "ref-test"]
        )

        let group = DispatchGroup()

        // Call makeRef from the socket queue (as it happens in production via push/startTimeout)
        for _ in 0..<100 {
            group.enter()
            socket.queue.async {
                let ref = socket.makeRef()
                XCTAssertNotNil(UInt64(ref), "makeRef returned invalid value: \(ref)")
                group.leave()
            }
        }

        // Simultaneously connect/disconnect from external threads
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                socket.connect()
                usleep(UInt32.random(in: 100...1000))
                socket.disconnect()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 15)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }

    // MARK: - Release Callbacks Under Contention

    /// Verifies that releaseCallbacks() can be called safely while
    /// other threads are registering callbacks. Both sides use
    /// SynchronizedArray which provides its own thread safety.
    func testReleaseCallbacksUnderContention_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "release-test"]
        )

        let group = DispatchGroup()

        for _ in 0..<30 {
            group.enter()
            DispatchQueue.global().async {
                _ = socket.onOpen { }
                _ = socket.onClose { }
                _ = socket.onError { _ in }
                _ = socket.onMessage { _ in }
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                usleep(UInt32.random(in: 50...500))
                socket.releaseCallbacks()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 15)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }

    // MARK: - Full Lifecycle Stress Test

    /// End-to-end stress test that mimics a real app scenario:
    /// connect, create channel, receive errors, reconnect, disconnect.
    /// All happening concurrently from different threads.
    func testFullLifecycleStress_shouldNotCrash() {
        let socket = Socket(
            "wss://invalid.example.com/socket",
            params: ["token": "lifecycle-test"]
        )
        socket.logger = { _ in }

        let group = DispatchGroup()

        // Register some callbacks
        _ = socket.onOpen { }
        _ = socket.onClose { }
        _ = socket.onError { _ in }

        // Rapid connect/disconnect cycles
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                socket.connect()
                usleep(UInt32.random(in: 500...5000))
                socket.disconnect()
                group.leave()
            }
        }

        // Simulate transport errors arriving on the queue
        for _ in 0..<20 {
            group.enter()
            socket.queue.async {
                let error = NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [
                    NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
                ])
                socket.onError(error: error, response: nil)
                socket.onClose(code: 999, reason: "network lost")
                group.leave()
            }
        }

        // Create and remove channels
        for index in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                let channel = socket.channel("room:\(index)")
                usleep(UInt32.random(in: 1000...3000))
                socket.remove(channel)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "Timed out - possible deadlock")
    }
}
