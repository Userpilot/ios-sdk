//
//  ScanDebouncer.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Coalesces a burst of "the screen changed!" signals into a single SwiftUI
//  scan, and gates each fire on main-run-loop idleness.
//
//  The idle gate is load-bearing for SwiftUI graph safety: the scan block only
//  fires when the run loop is NOT in UITrackingRunLoopMode, so the view graph
//  is not walked from deferred work during active touch tracking. This native
//  idle check is why scan scheduling uses its own debouncer rather than EventDebounce.
//

import UIKit

/// Scheduling/cancellation are any-thread. The injected queue delivers actions outside the lock;
/// native scan callers use main so the tracking-run-loop check and UIKit reads stay together.
internal final class ScanDebouncer {

    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?
    private let lock = NSLock()
    private let action: () -> Void

    init(delay: TimeInterval = 0.5, queue: DispatchQueue = .main, action: @escaping () -> Void) {
        self.delay = delay
        self.queue = queue
        self.action = action
    }

    func schedule() {
        let item = lock.withLock {
            workItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.fireIfSafe() }
            workItem = item
            return item
        }
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func fireNow() {
        lock.withLock {
            workItem?.cancel()
            workItem = nil
        }
        queue.async { [weak self] in self?.fireIfSafe() }
    }

    func cancel() {
        lock.withLock {
            workItem?.cancel()
            workItem = nil
        }
    }

    // MARK: - Idle gate

    private func fireIfSafe() {
        // If something is actively tracking touches (scroll views during a
        // drag, modal transitions), reschedule. This is the gate that prevents
        // the SwiftUI graph from being walked mid-mutation.
        if Self.isMainRunLoopTracking() {
            schedule()
            return
        }
        action()
    }

    /// True while the main run loop is in `UITrackingRunLoopMode`
    /// (a scroll/drag is in progress).
    static func isMainRunLoopTracking() -> Bool {
        guard let mode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain()) else { return false }
        // .tracking corresponds to UITrackingRunLoopMode — touches + scroll.
        // `CFRunLoopMode` wraps a `CFString`; compare via its `rawValue`.
        return mode != .commonModes
            && CFStringCompare(mode.rawValue, "UITrackingRunLoopMode" as CFString, []) == .compareEqualTo
    }
}
