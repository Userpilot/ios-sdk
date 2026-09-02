//
//  PreviewSessionTracker.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Tracks the active preview request and rejects stale asynchronous responses.
internal final class PreviewSessionTracker {

    private let lock = NSLock()
    private var nextId: UInt64 = 0
    private var activeId: UInt64?

    func begin() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        activeId = nextId
        return nextId
    }

    func isCurrent(_ id: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeId == id
    }

    func isActive() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeId != nil
    }

    @discardableResult
    func finish(_ id: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard activeId == id else { return false }
        activeId = nil
        return true
    }

    func cancel() {
        lock.lock()
        activeId = nil
        lock.unlock()
    }
}
