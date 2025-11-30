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

/// A thread-safe read-write lock for managing concurrent access to shared resources.
/// Supports multiple concurrent reads but ensures exclusive writes.
internal class ReadWriteLock {

    // MARK: - Properties

    /// A concurrent dispatch queue that manages read and write operations.
    /// - Concurrent reads are allowed.
    /// - Writes are executed exclusively using a barrier.
    private let concurrentQueue = DispatchQueue(
        label: Constants.DispatchQueues.event,
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .workItem
    )

    // MARK: - Public Methods

    /**
     Executes a closure in a read-only context.
     
     Multiple read operations can occur concurrently. This is useful for cases where
     reading shared resources does not modify them.
     
     - Parameter closure: The closure that performs read operations. Executed synchronously on the queue.
     */
    func read(closure: () -> Void) {
        concurrentQueue.sync {
            closure()
        }
    }

    /**
     Executes a closure in a write context.
     
     Write operations are performed exclusively. While a write is in progress, all other
     reads and writes are blocked. This ensures safe mutation of shared resources.
     
     - Parameter closure: The closure that performs write operations. Executed
     asynchronously with a barrier on the queue.
     */
    func write(closure: @escaping () -> Void) {
        concurrentQueue.async(flags: .barrier) {
            closure()
        }
    }
}
