//
//  AtomicReference.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A simple thread-safe atomic reference wrapper.
//

import Foundation

/// A thread-safe generic reference value that may be updated atomically.
/// This class mimics the behavior of Kotlin's AtomicReference<T>.
internal class AtomicReference<T> {
    private var _value: T
    private let lock = NSLock()

    /// Creates a new AtomicReference with the given initial value.
    /// - Parameter initialValue: The initial value
    init(_ initialValue: T) {
        self._value = initialValue
    }

    /// Gets or sets the current value atomically.
    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }

    /// Atomically sets the value to the given updated value and returns the old value.
    /// - Parameter newValue: The new value
    /// - Returns: The previous value
    func getAndSet(_ newValue: T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let oldValue = _value
        _value = newValue
        return oldValue
    }

    /// Atomically sets the value to the given updated value if the current value equals the expected value.
    /// - Parameters:
    ///   - expected: The expected value
    ///   - new: The new value
    /// - Returns: true if successful, false if the actual value was not equal to the expected value
    @discardableResult
    func compareAndSet(expected: T, new: T) -> Bool where T: Equatable {
        lock.lock()
        defer { lock.unlock() }
        if _value == expected {
            _value = new
            return true
        }
        return false
    }

    /// Performs an atomic operation with the current value.
    /// - Parameter block: A closure that receives the current value and returns a new value
    /// - Returns: The new value after the operation
    @discardableResult
    func update(_ block: (T) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        _value = block(_value)
        return _value
    }

    /// Performs an atomic read operation with the current value.
    /// - Parameter block: A closure that receives the current value
    /// - Returns: The result of the block
    func read<R>(_ block: (T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return block(_value)
    }
}

// MARK: - Usage Example
/*
let atomicRef = AtomicReference<String>("initial")

// Simple get/set
atomicRef.value = "updated"
print(atomicRef.value) // "updated"

// Get and set atomically
let oldValue = atomicRef.getAndSet("newest")
print("Old: \(oldValue), New: \(atomicRef.value)") // Old: updated, New: newest

// Compare and set
let success = atomicRef.compareAndSet(expected: "newest", new: "final")
print("CAS Success: \(success), Value: \(atomicRef.value)") // true, final

// Update with transformation
let newValue = atomicRef.update { current in
    return current.uppercased()
}
print("New value: \(newValue)") // FINAL

// Thread-safe usage
let ref = AtomicReference<Int>(0)
let group = DispatchGroup()

for i in 0..<1000 {
    group.enter()
    DispatchQueue.global().async {
        ref.update { $0 + 1 }
        group.leave()
    }
}

group.wait()
print("Final value: \(ref.value)") // 1000
*/
