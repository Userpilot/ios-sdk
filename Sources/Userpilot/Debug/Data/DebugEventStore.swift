//
//  DebugEventStore.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns debugger recording and bounded per-channel history for one SDK instance.
//

import Foundation

/// Recording, reset and buffer updates share one lock. UI observers receive invalidations, not stale snapshots.
internal protocol DebugEventStoring: AnyObject {
    func start()
    func stop()
    func reset()
    func record(_ event: Event)
    func record(_ event: SDKEvent)
    func events(for channel: DebugEventChannel) -> [DebugEvent]
    func observe(_ channel: DebugEventChannel, handler: @escaping () -> Void) -> UUID
    func removeObserver(_ id: UUID)
}

internal final class DebugEventStore: DebugEventStoring {

    static let maxEvents = 50

    private let lock = NSLock()
    private let mapper = DebugEventMapper()
    private var isStarted = false
    private var buffers: [DebugEventChannel: [DebugEvent]] = [:]
    private var observers: [UUID: (channel: DebugEventChannel, handler: () -> Void)] = [:]

    func start() {
        lock.withLock { isStarted = true }
    }

    func stop() {
        lock.withLock { isStarted = false }
    }

    /// Clearing is synchronous: there is no pending event bus that can repopulate history after logout.
    func reset() {
        let handlers = lock.withLock {
            buffers.removeAll()
            return observers.values.map(\.handler)
        }
        handlers.forEach { $0() }
    }

    func record(_ event: Event) {
        record { mapper.fromAnalytics(event) }
    }

    func record(_ event: SDKEvent) {
        record { mapper.fromInternal(event) }
    }

    func events(for channel: DebugEventChannel) -> [DebugEvent] {
        lock.withLock { buffers[channel] ?? [] }
    }

    /// Callers read the latest events on their UI queue, so a delayed update cannot undo a reset.
    func observe(_ channel: DebugEventChannel, handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        lock.withLock { observers[id] = (channel, handler) }
        handler()
        return id
    }

    func removeObserver(_ id: UUID) {
        lock.withLock { observers[id] = nil }
    }

    /// Mapping is deferred until recording is enabled, and IDs follow the same order as buffer admission.
    private func record(_ makeEvent: () -> DebugEvent) {
        let handlers: [() -> Void] = lock.withLock {
            guard isStarted else { return [] }
            let event = makeEvent()
            var buffer = buffers[event.channel] ?? []
            buffer.insert(event, at: 0)
            if buffer.count > Self.maxEvents { buffer.removeLast() }
            buffers[event.channel] = buffer
            return observers.values.filter { $0.channel == event.channel }.map(\.handler)
        }
        // UI code may reenter the store; no external callback runs under the state lock.
        handlers.forEach { $0() }
    }
}
