//
//  SocketTestSupport.swift
//  Userpilot SDK
//
//  Created by Userpilot on 07/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shared transport and subscription doubles for socket tests. They record real
//  Phoenix serialization without opening a network connection.
//

import Foundation
@testable import Userpilot

final class RecordingSocketSubscription: SocketSubscription {
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

final class FakePhoenixTransport: PhoenixTransport {
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

struct SentPush {
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
