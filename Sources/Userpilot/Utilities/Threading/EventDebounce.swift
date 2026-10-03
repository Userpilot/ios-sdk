//
//  EventDebounce.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/03/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Per-key debouncing: repeated `schedule` calls reset the timer; after `delay`
//  of quiet time, the latest value is delivered once on `deliveryQueue`.
//
//  Thread-safety contract:
//  - `schedule`, `cancelAll`, and `shutdown` are safe to call from any thread.
//  - `onDeliver` is always invoked on `deliveryQueue` (default: `.main`).
//  - UIKit callers (e.g. `cacheTextFieldChanged`) must call from the main thread,
//    as `UIView` properties are accessed before the hop to the internal queue.
//

import Foundation

internal final class EventDebounce<Value> {

    // MARK: - Properties

    private let delay: TimeInterval
    private let deliveryQueue: DispatchQueue
    private let onDeliver: (Value) -> Void

    /// `true` when `deliveryQueue` is the main queue, so `flushPending()` can deliver inline
    /// when it is already called from the main thread.
    private let deliversOnMainQueue: Bool

    /// Serial queue that owns all mutable state. Every read/write of
    /// `workItems` and `latestValues` must happen on this queue.
    private let queue: DispatchQueue

    /// Maps a debounce key to its pending work item.
    private var workItems: [String: DispatchWorkItem] = [:]

    /// Values remain pending after timer expiry until delivery claims them. This lets cancellation
    /// drop queued callbacks and lets a main-thread flush keep text changes ahead of screen changes.
    private var latestValues: [String: (id: UUID, value: Value)] = [:]

    // MARK: - Initialization

    /// - Parameters:
    ///   - delay: Quiet period after the last `schedule` call before `onDeliver` runs.
    ///   - deliveryQueue: Queue on which `onDeliver` is invoked (default: `.main`).
    ///   - queue: Serial state queue, injectable for tests. Must be separate from `deliveryQueue`.
    ///   - onDeliver: Called with the latest value for that key when the debounce fires.
    ///                Always invoked on `deliveryQueue`. Must be thread-safe.
    init(
        delay: TimeInterval,
        deliveryQueue: DispatchQueue = .main,
        queue: DispatchQueue = DispatchQueue(label: Constants.DispatchQueues.debounceQueue),
        onDeliver: @escaping (Value) -> Void
    ) {
        self.delay = delay
        self.queue = queue
        self.deliveryQueue = deliveryQueue
        self.onDeliver = onDeliver
        self.deliversOnMainQueue = deliveryQueue === DispatchQueue.main
    }

    // MARK: - Public Methods

    /// Schedules delivery of `value` for `key`.
    /// Resets the timer if `key` was already pending, keeping only the latest value.
    /// Safe to call from any thread.
    func schedule(key: String, value: Value) {
        queue.async { [weak self] in
            guard let self else { return }
            self.scheduleLocked(key: key, value: value)
        }
    }

    /// Cancels timers and queued deliveries that have not yet been claimed to run.
    /// A callback already claimed by `deliveryQueue` is allowed to finish; callbacks run outside `queue`.
    /// Safe from `onDeliver`, but must not be called from the private owning queue.
    func cancelAll() {
        queue.sync {
            cancelTimersLocked()
            latestValues.removeAll()
        }
    }

    /// Cancels pending work. Alias for `cancelAll()` — call before teardown.
    func shutdown() {
        cancelAll()
    }

    /// Flushes buffered values, including values whose timers have already expired.
    ///
    /// The opposite of `cancelAll()`: values are delivered instead of dropped. Use it when the caller
    /// is about to publish an event that the pending values must precede — e.g. a manual `screen`
    /// call must not overtake a text change the user made on the previous screen.
    ///
    /// When `deliveryQueue` is the main queue and the caller is already on the main thread, the
    /// handler runs inline, so the caller keeps the ordering guarantee. Otherwise delivery is
    /// dispatched onto `deliveryQueue` as usual.
    func flushPending() {
        let pending: [(key: String, id: UUID)] = queue.sync {
            cancelTimersLocked()
            return latestValues.map { (key: $0.key, id: $0.value.id) }
        }
        guard !pending.isEmpty else { return }

        if deliversOnMainQueue, Thread.isMainThread {
            pending.forEach { deliverIfPending(key: $0.key, identifier: $0.id) }
            return
        }

        deliveryQueue.async { [weak self] in
            guard let self else { return }
            pending.forEach { self.deliverIfPending(key: $0.key, identifier: $0.id) }
        }
    }

    // MARK: - Private Methods

    /// Must be called on `queue`.
    private func scheduleLocked(key: String, value: Value) {
        workItems[key]?.cancel()
        let identifier = UUID()
        latestValues[key] = (identifier, value)

        // Capture the identity rather than the work item, which would retain its own closure.
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.latestValues[key]?.id == identifier else { return }
            self.workItems.removeValue(forKey: key)
            self.deliveryQueue.async { [weak self] in
                self?.deliverIfPending(key: key, identifier: identifier)
            }
        }
        workItems[key] = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Cancels timers while retaining values until delivery or cancellation claims them.
    /// Must be called on `queue`.
    private func cancelTimersLocked() {
        for item in workItems.values {
            item.cancel()
        }
        workItems.removeAll()
    }

    /// Called on `deliveryQueue` (or inline on main for a flush). Claim under the owner queue,
    /// then invoke outside it so a handler can schedule, cancel, or flush without deadlocking.
    private func deliverIfPending(key: String, identifier: UUID) {
        let pending: Value? = queue.sync {
            guard latestValues[key]?.id == identifier else { return nil }
            return latestValues.removeValue(forKey: key)?.value
        }
        guard let pending else { return }
        onDeliver(pending)
    }
}
