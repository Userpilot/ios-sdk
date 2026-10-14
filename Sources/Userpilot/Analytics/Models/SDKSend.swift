//
//  SDKSend.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Holds an in-memory SDK queue entry with its admission check and completion callback.
//

/// An in-memory SDK queue entry; transport callbacks are never part of the event payload or storage.
internal struct SDKSend {
    let event: SDKEvent

    /// Rechecked during analytics admission, socket submission and reply handling.
    /// Must be fast, side-effect-free and safe across the calling queues.
    let shouldSend: () -> Bool

    /// Receives the transport result while this request remains valid.
    /// Cancellation can suppress this callback.
    let completion: SocketCompletion?
}
