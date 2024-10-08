//
//  MulticastDelegate.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
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
final class MulticastDelegate<T> {

    // MARK: - Properties

    /// A set of weak references to the delegates, preventing retain cycles.
    /// `NSHashTable.weakObjects()` ensures delegates are automatically removed when deallocated.
    private let delegates: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    // MARK: - Methods

    /// Adds a new delegate to the multicast list.
    /// - Parameter delegate: The delegate to be added.
    func add(_ delegate: T) {
        // Add the delegate only if it's not already in the list.
        if !delegates.contains(delegate as AnyObject) {
            delegates.add(delegate as AnyObject)
        }
    }

    /// Removes a specific delegate from the multicast list.
    /// - Parameter delegateToRemove: The delegate to be removed.
    func remove(_ delegateToRemove: T) {
        // Iterating in reverse to safely remove elements while iterating.
        for delegate in delegates.allObjects.reversed() where delegate === delegateToRemove as AnyObject {
            delegates.remove(delegate)
        }
    }

    /// Invokes a closure on all the delegates in the multicast list.
    /// - Parameter invocation: A closure that takes a delegate and performs an action.
    func invoke(_ invocation: (T) -> Void) {
        // Ensure that force-casting is safe by iterating through the delegates.
        for delegate in delegates.allObjects.reversed() {
            guard let castedDelegate = delegate as? T else { continue }
            invocation(castedDelegate)
        }
    }
}
