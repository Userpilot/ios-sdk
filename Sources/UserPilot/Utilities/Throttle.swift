//
//  Throttle.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The Throttle class is used to implement throttling logic.
//  It ensures that a block of code is not executed more frequently than a specified minimum delay.
//
//  Throttling is useful for reducing the rate at which certain tasks, such as API calls or UI updates,
//  are performed, especially when they are triggered frequently within a short time span.
//

import Foundation

internal class Throttle {

    // MARK: - Properties

    /// A `DispatchWorkItem` representing the work to be executed.
    /// It can be cancelled if new work is scheduled before the previous one finishes.
    private var workItem: DispatchWorkItem = DispatchWorkItem(block: { })

    /// The time at which the most recent task was executed.
    /// Initialized to the distant past to ensure the first task runs immediately.
    private var previousRun: Date = Date.distantPast

    /// The dispatch queue on which the throttled work will be executed.
    /// Defaults to a serial queue created specifically for the throttle.
    private let queue: DispatchQueue

    /// The minimum delay between consecutive executions of the throttled work.
    private let delay: TimeInterval

    // MARK: - Initialization

    /// Initializes the `Throttle` instance with a minimum delay and an optional dispatch queue.
    /// - Parameters:
    ///   - minimumDelay: The minimum delay between consecutive executions.
    ///   - queue: The dispatch queue where the throttled work will be executed. Defaults
    ///    to a serial queue named "userpilot-throttle-queue".
    init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue(label: "userpilot-throttle-queue")) {
        self.delay = minimumDelay
        self.queue = queue
    }

}

// MARK: - Helper method
internal extension Throttle {

    /// Executes the provided block of code, ensuring it does not run more frequently than the minimum delay.
    /// If a new execution is requested before the delay period from the previous run has passed,
    /// the previous pending task will be cancelled and rescheduled.
    ///
    /// - Parameter block: The block of code to be throttled.
    func excute(_ block: @escaping () -> Void) {
        // Cancel the previous work item if it exists
        workItem.cancel()

        // Create a new work item to execute the block
        workItem = DispatchWorkItem { [weak self] in
            // Record the current time as the time of the most recent run
            self?.previousRun = Date()
            block()  // Execute the provided block
        }

        // Calculate the time interval to delay the execution.
        // If the previous run was earlier than the minimum delay, schedule 
        // immediately, otherwise wait for the remaining time.
        let deltaDelay = previousRun.timeIntervalSinceNow > delay ? 0 : delay

        // Schedule the work item on the dispatch queue after the calculated delay.
        queue.asyncAfter(deadline: .now() + Double(deltaDelay), execute: workItem)
    }

}
