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
    private let queue = DispatchQueue(label: DispatchQueueConstants.DEBOUNCE_QUEUE)

    /// Maps a debounce key to its pending work item.
    private var workItems: [String: DispatchWorkItem] = [:]

    /// Stores the most recent value for each pending key.
    private var latestValues: [String: Value] = [:]

    // MARK: - Initialization

    /// - Parameters:
    ///   - delay: Quiet period after the last `schedule` call before `onDeliver` runs.
    ///   - deliveryQueue: Queue on which `onDeliver` is invoked (default: `.main`).
    ///   - onDeliver: Called with the latest value for that key when the debounce fires.
    ///                Always invoked on `deliveryQueue`. Must be thread-safe.
    init(
        delay: TimeInterval,
        deliveryQueue: DispatchQueue = .main,
        onDeliver: @escaping (Value) -> Void
    ) {
        self.delay = delay
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

    /// Cancels all pending work and drops buffered values without delivering them.
    ///
    /// - Note: "cancel" accurately reflects the behavior — values are discarded,
    ///   not flushed/delivered. Renamed from `clear()` to avoid ambiguity.
    ///
    /// - Important: Do NOT call this from within the internal serial queue
    ///   (e.g. from inside `onDeliver` if `deliveryQueue === queue`) or a
    ///   deadlock will occur. In practice this is not an issue because
    ///   `deliveryQueue` defaults to `.main` and is a different queue.
    func cancelAll() {
        // `queue.sync` is intentional: callers of `cancelAll()` need a
        // synchronous guarantee that no further deliveries will occur after
        // this call returns. Safe as long as the caller is not already on
        // `queue` — see the doc-comment warning above.
        queue.sync {
            cancelAllLocked()
        }
    }

    /// Cancels pending work. Alias for `cancelAll()` — call before teardown.
    func shutdown() {
        cancelAll()
    }

    /// Delivers every buffered value right away and clears the pending state.
    ///
    /// The opposite of `cancelAll()`: values are delivered instead of dropped. Use it when the caller
    /// is about to publish an event that the pending values must precede — e.g. a manual `screen`
    /// call must not overtake a text change the user made on the previous screen.
    ///
    /// When `deliveryQueue` is the main queue and the caller is already on the main thread, the
    /// handler runs inline, so the caller keeps the ordering guarantee. Otherwise delivery is
    /// dispatched onto `deliveryQueue` as usual.
    func flushPending() {
        let pending: [Value] = queue.sync {
            drainPendingLocked()
        }
        guard !pending.isEmpty else { return }

        if deliversOnMainQueue, Thread.isMainThread {
            pending.forEach { onDeliver($0) }
            return
        }

        deliveryQueue.async { [weak self] in
            guard let self else { return }
            pending.forEach { self.onDeliver($0) }
        }
    }

    // MARK: - Private Methods

    /// Must be called on `queue`.
    private func scheduleLocked(key: String, value: Value) {
        // Cancel any existing timer for this key.
        workItems[key]?.cancel()

        // Always keep the freshest value.
        latestValues[key] = value

        // FIX: Schedule on `queue` (not DispatchQueue.main) so that:
        //  1. `cancel()` is atomic — if the item hasn't started on `queue`
        //     yet, cancelling it prevents it from ever running.
        //  2. The work item body runs directly on `queue`, so no second
        //     `queue.async` hop is needed and all state access is safe.
        //  3. The stale-item identity guard remains correct and sufficient.
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Identity check: if a newer item has replaced this one,
            // bail out. This is the canonical GCD stale-cancellation pattern.
            guard self.workItems[key] === workItem else { return }
            self.workItems.removeValue(forKey: key)
            guard let toSend = self.latestValues.removeValue(forKey: key) else { return }
            self.deliver(toSend)
        }

        workItems[key] = workItem
        // Schedule on the internal serial queue — NOT DispatchQueue.main.
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Must be called on `queue`.
    private func cancelAllLocked() {
        _ = drainPendingLocked()
    }

    /// Cancels every pending work item and returns the buffered values.
    /// Must be called on `queue`.
    private func drainPendingLocked() -> [Value] {
        for (_, item) in workItems {
            item.cancel()
        }
        workItems.removeAll()

        let pending = Array(latestValues.values)
        latestValues.removeAll()
        return pending
    }

    /// Hops to `deliveryQueue` and invokes the caller-supplied handler.
    /// Always called from `queue`; delivery always lands on `deliveryQueue`.
    private func deliver(_ value: Value) {
        deliveryQueue.async { [weak self] in
            guard let self else { return }
            self.onDeliver(value)
        }
    }
}
