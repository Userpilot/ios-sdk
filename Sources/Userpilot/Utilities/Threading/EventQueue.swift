//
//  EventQueue.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 02/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Thread-safe event queue with optional prioritization for internal events.
//

import Foundation

internal class EventQueue {
    private var queue: [Event] = []
    private let dispatchQueue = DispatchQueue(label: "events_queue", attributes: .concurrent)

    // MARK: - Write operations (exclusive)

    public func enqueue(_ event: Event, isInternalEvent: Bool = false) {
        dispatchQueue.sync(flags: .barrier) {
            if isInternalEvent {
                self.queue.insert(event, at: 0)
            } else {
                self.queue.append(event)
            }
        }
    }

    @discardableResult
    public func dequeue() -> Event? {
        dispatchQueue.sync(flags: .barrier) {
            if !queue.isEmpty {
                return queue.removeFirst()
            }
            return nil
        }
    }

    public func clear() {
        dispatchQueue.sync(flags: .barrier) {
            self.queue.removeAll()
        }
    }

    public func deleteFirst() {
        dispatchQueue.sync(flags: .barrier) {
            if !self.queue.isEmpty {
                self.queue.removeFirst()
            }
        }
    }

    // MARK: - Read operations (shared reads)

    public func peek() -> Event? {
        dispatchQueue.sync {
            queue.first
        }
    }

    public func size() -> Int {
        dispatchQueue.sync {
            queue.count
        }
    }

    public func isEmpty() -> Bool {
        dispatchQueue.sync {
            queue.isEmpty
        }
    }

    public func getAll() -> [Event] {
        dispatchQueue.sync {
            queue
        }
    }

    public func getAndClear() -> [Event] {
        dispatchQueue.sync(flags: .barrier) {
            let events = queue
            queue.removeAll()
            return events
        }
    }

    public func contains(_ event: Event, where compare: (Event, Event) -> Bool) -> Bool {
        dispatchQueue.sync {
            queue.contains(where: { compare($0, event) })
        }
    }

    public func find(where predicate: (Event) -> Bool) -> Event? {
        dispatchQueue.sync {
            queue.first(where: predicate)
        }
    }

    public func getFirst() -> Event? {
        dispatchQueue.sync {
            queue.first
        }
    }
}
