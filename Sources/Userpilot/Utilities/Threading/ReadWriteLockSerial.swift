//
//  ReadWriteLockSerial.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 27/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  A thread-safe serial lock that ensures sequential execution of both read and write operations.
//  Unlike traditional read-write locks, this implementation enforces strict serialization, allowing
//  only one operation (read or write) to execute at a time.
//

import Foundation

/// A serial execution lock that ensures thread-safe access to shared resources.
/// This implementation enforces sequential execution of both read and write operations,
/// preventing race conditions in concurrent environments.
internal class ReadWriteLockSerial {

    // MARK: - Properties

    /// A serial dispatch queue used to synchronize read and write operations.
    private let serialQueue: DispatchQueue

    // MARK: - Initialization

    /// Initializes a new `ReadWriteLockSerial` instance with a specified label for the dispatch queue.
    ///
    /// - Parameter label: A string used to identify the dispatch queue. Useful for debugging and profiling.
    init(label: String) {
        serialQueue = DispatchQueue(
            label: label,
            qos: .utility,
            autoreleaseFrequency: .workItem
        )
    }

    // MARK: - Methods

    /// Executes a closure in a sequential read context. Ensures no concurrent execution with other reads or writes.
    ///
    /// - Parameter closure: A closure that performs read operations.
    /// - Returns: The result of the read operation.
    func read<T>(closure: () -> T) -> T {
        return serialQueue.sync {
            closure()
        }
    }

    /// Executes a closure in a sequential write context. Ensures exclusive access for writing operations.
    ///
    /// - Parameter closure: A closure that performs write operations.
    /// - Returns: The result of the write operation.
    func write<T>(closure: () -> T) -> T {
        return serialQueue.sync {
            closure()
        }
    }
}
