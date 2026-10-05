//
//  SocketSubscription.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines callbacks for socket lifecycle, backend messages and individual push results.
//

import Foundation

/// A single push's response and success status, delivered to its submitting operation.
internal typealias SocketCompletion = (Message, Bool) -> Void

/// Receives socket lifecycle, push results and backend messages, like Android's socket listener.
internal protocol SocketSubscription: AnyObject {

    /// Called after the current connection closes.
    func onSocketClosed()

    /// Called after the channel successfully joins.
    func onSocketOpened()

    /// Reports a push result with its original payload and the response's resolved event name.
    func onSocketEventSent(
        _ event: String,
        _ payload: Payload,
        _ message: Message,
        _ status: Bool
    )

    /// Receives a new backend message.
    func onNewMessage(_ message: Message)
}

/// Swift protocol defaults keep each callback optional, as Android's listener interface does.
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
