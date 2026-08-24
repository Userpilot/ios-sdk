//
//  DebugEventStore.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Per-channel ring buffer of debugger events.
///
/// Collects from the bus only after `start()` so a closed debugger does not retain history.
internal protocol DebugEventStoring: AnyObject {
    func start()
    func stop()
    func reset()
    func events(for channel: DebugEventChannel) -> [DebugEvent]
    func observe(_ channel: DebugEventChannel, handler: @escaping ([DebugEvent]) -> Void) -> UUID
    func removeObserver(_ id: UUID)
}

internal final class DebugEventStore: DebugEventStoring {

    static let maxEvents = 50

    private let bus: DebugEventBusing
    private let lock = NSLock()
    private var buffers: [DebugEventChannel: [DebugEvent]] = [
        .manual: [],
        .autoCapture: [],
        .internalSDK: []
    ]
    private var observers: [UUID: (channel: DebugEventChannel, handler: ([DebugEvent]) -> Void)] = [:]
    private var subscription: UUID?
    private var started = false

    init(bus: DebugEventBusing) {
        self.bus = bus
    }

    init(container: DIContainer) {
        self.bus = container.resolve(DebugEventBusing.self)
    }

    func events(for channel: DebugEventChannel) -> [DebugEvent] {
        lock.lock()
        defer { lock.unlock() }
        return buffers[channel] ?? []
    }

    func start() {
        lock.lock()
        if started {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()
        subscription = bus.addSubscriber { [weak self] event in
            self?.append(event)
        }
    }

    func stop() {
        lock.lock()
        started = false
        let token = subscription
        subscription = nil
        lock.unlock()
        if let token {
            bus.removeSubscriber(token)
        }
    }

    func reset() {
        lock.lock()
        for channel in DebugEventChannel.allCases {
            buffers[channel] = []
        }
        let snapshot = observers
        lock.unlock()
        for entry in snapshot.values {
            entry.handler([])
        }
    }

    func observe(
        _ channel: DebugEventChannel,
        handler: @escaping ([DebugEvent]) -> Void
    ) -> UUID {
        let id = UUID()
        lock.lock()
        observers[id] = (channel, handler)
        let current = buffers[channel] ?? []
        lock.unlock()
        handler(current)
        return id
    }

    func removeObserver(_ id: UUID) {
        lock.lock()
        observers[id] = nil
        lock.unlock()
    }

    private func append(_ event: DebugEvent) {
        lock.lock()
        var buffer = buffers[event.channel] ?? []
        buffer.insert(event, at: 0)
        while buffer.count > Self.maxEvents {
            buffer.removeLast()
        }
        buffers[event.channel] = buffer
        let handlers = observers.values.compactMap { entry -> (([DebugEvent]) -> Void)? in
            entry.channel == event.channel ? entry.handler : nil
        }
        lock.unlock()
        for handler in handlers {
            handler(buffer)
        }
    }
}
