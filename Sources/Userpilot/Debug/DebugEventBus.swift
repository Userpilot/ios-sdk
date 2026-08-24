//
//  DebugEventBus.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Multicast fan-out for debugger events. Emit is a no-op when nobody is subscribed.
internal protocol DebugEventBusing: AnyObject {
    var subscriberCount: Int { get }
    func emit(_ event: DebugEvent)
    func addSubscriber(_ handler: @escaping (DebugEvent) -> Void) -> UUID
    func removeSubscriber(_ id: UUID)
}

internal final class DebugEventBus: DebugEventBusing {

    private let lock = NSLock()
    private var subscribers: [UUID: (DebugEvent) -> Void] = [:]

    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return subscribers.count
    }

    func emit(_ event: DebugEvent) {
        let handlers: [(DebugEvent) -> Void]
        lock.lock()
        handlers = Array(subscribers.values)
        lock.unlock()
        guard !handlers.isEmpty else { return }
        for handler in handlers {
            handler(event)
        }
    }

    func addSubscriber(_ handler: @escaping (DebugEvent) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        subscribers[id] = handler
        lock.unlock()
        return id
    }

    func removeSubscriber(_ id: UUID) {
        lock.lock()
        subscribers[id] = nil
        lock.unlock()
    }

    init() {}

    init(container: DIContainer) {
        _ = container
    }
}
