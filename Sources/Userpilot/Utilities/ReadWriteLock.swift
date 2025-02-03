//
//  ReadWriteLock.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A thread-safe read-write lock implementation that allows concurrent reads and exclusive writes.
//  Useful for scenarios where multiple threads need to read data simultaneously but only one thread
//  can modify data at a time.
//

import Foundation

/// A thread-safe read-write lock implementation for managing concurrent access to shared resources.
/// Allows multiple threads to read data simultaneously but ensures exclusive access for writing operations.
internal class ReadWriteLock {

    // MARK: - Properties

    /// A concurrent dispatch queue used to manage read and write operations.
    private let concurrentQueue: DispatchQueue

    // MARK: - Initialization

    /// Initializes a new `ReadWriteLock` instance with a specified label for the dispatch queue.
    ///
    /// - Parameter label: A string used to identify the dispatch queue. Helps in debugging and profiling.
    init(label: String) {
        concurrentQueue = DispatchQueue(label: label,
                                        qos: .utility,
                                        attributes: .concurrent,
                                        autoreleaseFrequency: .workItem)
    }

    // MARK: - Methods

    /// Executes a closure in a read-only context. Multiple read operations can occur concurrently.
    ///
    /// - Parameter closure: A closure that performs read operations. It is executed synchronously on the queue.
    func read(closure: () -> Void) {
        concurrentQueue.sync {
            closure()
        }
    }

    /// Executes a closure in a write context. Write operations are performed exclusively, blocking
    ///  other reads and writes.
    ///
    /// - Parameter closure: A closure that performs write operations. It is executed asynchronously 
    /// with barrier flag on the queue.
    func write(closure: @escaping () -> Void) {
        concurrentQueue.async(flags: .barrier) {
            closure()
        }
    }
}
