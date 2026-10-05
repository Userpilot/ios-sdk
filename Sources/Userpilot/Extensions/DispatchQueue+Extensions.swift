//
//  DispatchQueue+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Provides shared queues and helpers for asynchronous dispatch and immediate main-thread work.
//

import Foundation

/*
QoS Priority Levels (highest to lowest):
.userInteractive - User is actively waiting, UI updates, animations
.userInitiated - User requested action, but can wait briefly
.default - General work
.utility - Long-running tasks, can take minutes
.background - Not visible to user, can take hours
*/

internal enum QueueType {
    case main
    case background
    case lowPriority
    case highPriority

    /// The shared serial background queue.
    ///
    /// Stored, not built per access: as a computed value every `performOn(.background)` call got its
    /// own queue, so work dispatched to `.background` was never serialized against other work on it.
    private static let backgroundQueue = DispatchQueue(
        label: Constants.DispatchQueues.background,
        qos: .background,
        target: nil
    )

    var queue: DispatchQueue {
        switch self {
        case .main:
            return DispatchQueue.main
        case .background:
            return QueueType.backgroundQueue
        case .lowPriority:
            return DispatchQueue.global(qos: .utility)
        case .highPriority:
            return DispatchQueue.global(qos: .userInitiated)
        }
    }
}

/// Always enqueues, even on the destination queue; serial queues preserve submission order.
internal func performOn(_ queueType: QueueType, closure: @escaping () -> Void) {
    queueType.queue.async(execute: closure)
}

/// Safe from any thread: runs inline on main, otherwise enqueues asynchronously on main.
/// Use `performOn(.main)` when work must wait for a later queue turn, even when called on main.
internal func performOnMain(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        performOn(.main, closure: closure)
    }
}
