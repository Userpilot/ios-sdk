//
//  SocketRequestDispatchTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Guards dynamic protocol dispatch so convenience sends keep their cancellation and ACK callbacks.
//

import XCTest
@testable import Userpilot

final class SocketRequestDispatchTests: XCTestCase {
    func testConvenienceSendForwardsCompletionThroughProtocol() {
        let concrete = RecordingRequestSocket()
        let socket: SocketManaging = concrete
        var received = false

        socket.publish("track", payload: ["event_name": "Purchase"], shouldSend: { true }, completion: { _, success in
            received = success
        })

        XCTAssertEqual(concrete.requestCount, 1)
        XCTAssertEqual(concrete.eventName, "track")
        XCTAssertEqual(concrete.payload?["event_name"] as? String, "Purchase")
        XCTAssertNil(concrete.userID)
        XCTAssertTrue(received)
        XCTAssertEqual(concrete.legacyPublishCount, 0)
    }

    func testConvenienceSendForwardsCancellationToConcreteImplementation() {
        let concrete = RecordingRequestSocket()
        let socket: SocketManaging = concrete
        socket.publish("track", payload: nil, shouldSend: { false }, completion: { _, _ in
            XCTFail("Cancelled request must not complete")
        })
        XCTAssertEqual(concrete.requestCount, 1)
        XCTAssertFalse(concrete.allowedToSend)
        XCTAssertEqual(concrete.legacyPublishCount, 0)
    }
}

private final class RecordingRequestSocket: SocketManaging {
    let isSocketOpened = true
    let isJoiningSocket = false
    let didCloseFromError = false
    let isShutdownState = false
    var requestCount = 0
    var legacyPublishCount = 0
    var eventName: String?
    var payload: Payload = nil
    var userID: String?
    var allowedToSend = false

    func connect() {}
    func close() {}
    func registerCallback(_ socketSubscription: SocketSubscription) {}
    func publish(_ eventName: String, payload: Payload) {
        legacyPublishCount += 1
    }

    func publish(
        _ eventName: String, payload: Payload, userID: String?,
        shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    ) {
        requestCount += 1
        self.eventName = eventName
        self.payload = payload
        self.userID = userID
        allowedToSend = shouldSend()
        if allowedToSend { completion?(Message(), true) }
    }
}
