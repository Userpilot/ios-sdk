//
//  MulticastDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  MulticastDelegate allows multiple delegates to be notified of an event or process.
//  It enables multicasting by holding weak references to delegates, avoiding retain cycles
//  and ensuring delegates are automatically removed when deallocated.
//

import Foundation

/// A property wrapper that allows a class or struct to use a multicast delegate pattern.
/// It provides an easy way to add, remove, and invoke multiple delegates.
@propertyWrapper
internal struct Multicast<T> {

    // MARK: - Properties

    /// The internal multicast delegate instance, initialized with an empty set of delegates.
    private var _wrappedValue: MulticastDelegate<T> = .init()

    /// Provides access to the `MulticastDelegate` instance for manual delegate handling.
    var projectedValue: MulticastDelegate<T> { _wrappedValue }

    /// `wrappedValue` is a computed property that should not be accessed directly.
    /// Instead, new delegates can be added via the `wrappedValue`.
    var wrappedValue: T {
        get {
            // It is not expected to access the value directly.
            fatalError(
                "The wrapped value should not be accessed directly. " +
                "Use the projectedValue ($) to manipulate the delegate."
            )
        }
        set {
            // Add the new value as a delegate.
            _wrappedValue.add(newValue)
        }
    }

    // MARK: - Initialization

    /// Default initializer.
    init() {}

}

/// A class that manages multiple delegates using weak references to prevent retain cycles.
///
/// Thread-safe. `NSLock` is not recursive, so callbacks must run outside it: `currentDelegates()`
/// is the only reader of the storage and `invoke` takes no lock. A subscriber registering from
/// inside its own callback — which happens on the socket thread — would otherwise deadlock.
internal final class MulticastDelegate<T> {

    // MARK: - Properties

    /// Guards `delegates`. `NSHashTable` is not thread-safe and the table is reached from the
    /// socket transport and push-resolution threads as well as the caller's.
    private let lock = NSLock()

    /// Weak references to the delegates, so registering never keeps a subscriber alive.
    private let delegates: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    // MARK: - Methods

    /// Adds a delegate, ignoring duplicates.
    func add(_ delegate: T) {
        let object = delegate as AnyObject
        lock.withLock {
            guard !delegates.contains(object) else { return }
            delegates.add(object)
        }
    }

    /// Removes a delegate.
    func remove(_ delegateToRemove: T) {
        let object = delegateToRemove as AnyObject
        lock.withLock {
            for delegate in delegates.allObjects where delegate === object {
                delegates.remove(delegate)
            }
        }
    }

    /// Invokes `invocation` on every live delegate. Holds no lock — see the note on the type.
    func invoke(_ invocation: (T) -> Void) {
        currentDelegates().forEach(invocation)
    }

    /// The only read of `delegates`. The snapshot holds each delegate strongly while the caller
    /// iterates it, so a subscriber cannot deallocate mid-callback.
    private func currentDelegates() -> [T] {
        lock.withLock {
            delegates.allObjects.reversed().compactMap { $0 as? T }
        }
    }
}
