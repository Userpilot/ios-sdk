//
//  SocketExtensionsTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class SocketExtensionsTests: XCTestCase {

    func testMessageIsInvalidWhenPayloadIsEmpty() {
        let message = Message(topic: "room", event: "ok", payload: [:])

        XCTAssertTrue(message.isInvalidMessage)
    }

    func testMessageIsInvalidForPhoenixCloseEvent() {
        let message = Message(topic: "room", event: "phx_close", payload: ["ok": true])

        XCTAssertTrue(message.isInvalidMessage)
    }

    func testMessageIsInvalidForPhoenixTopic() {
        let message = Message(topic: "phoenix", event: "ok", payload: ["ok": true])

        XCTAssertTrue(message.isInvalidMessage)
    }

    func testMessageIsValidWhenPayloadTopicAndEventAreUsable() {
        let message = Message(topic: "room", event: "ok", payload: ["ok": true])

        XCTAssertFalse(message.isInvalidMessage)
    }

    func testMessagePayloadUsesNestedResponseForPhoenixReplyPayloads() {
        let message = Message(
            topic: "room",
            event: "phx_reply",
            payload: [
                "status": "ok",
                "response": ["received": true]
            ]
        )

        XCTAssertEqual(message.status, "ok")
        XCTAssertEqual(message.payload["received"] as? Bool, true)
        XCTAssertFalse(message.isInvalidMessage)
    }
}
