//
//  PreviewSessionTracker.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Tracks the active preview request so stale asynchronous responses can be rejected.
//

import Foundation

/// Tracks the active preview request and rejects stale asynchronous responses.
///
/// A preview is opened from a deep link and then travels through `resetState`, a network fetch, and
/// the experience queue before anything renders. Any of those hops can be overtaken by a second
/// deep link or by a lifecycle reset, and the late response from the abandoned preview would
/// otherwise still render. Each attempt takes an id and every hop re-checks that it is still the
/// current one.
///
/// Thread-safe: the hops it guards run on the URLSession delegate queue, the experience queue, and
/// main.
internal final class PreviewSessionTracker {

    private let lock = NSLock()
    private var nextId: UInt64 = 0
    private var activeId: UInt64?

    /// Starts a new preview session, superseding any previous one.
    /// - Returns: The id to carry through this attempt's async hops.
    func begin() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        activeId = nextId
        return nextId
    }

    /// Whether `id` is still the active session — false once superseded or cancelled.
    func isCurrent(_ id: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeId == id
    }

    /// Whether any preview session is in flight.
    func isActive() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeId != nil
    }

    /// Closes `id` if it is still active.
    /// - Returns: `true` exactly once for the session that was current.
    @discardableResult
    func finish(_ id: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard activeId == id else { return false }
        activeId = nil
        return true
    }

    /// Abandons whatever session is active, so its pending responses are ignored.
    func cancel() {
        lock.lock()
        activeId = nil
        lock.unlock()
    }
}
