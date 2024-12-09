//
//  Constants.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// A utility class that ensures a function is only called after a specified delay has passed
// since the last call. Useful for managing repetitive actions like user input or API requests.
//

import Foundation

internal class Debouncer {

    // MARK: - Properties

    /// The delay interval (in seconds) before the action is executed.
    private let delay: TimeInterval

    /// The dispatch queue on which the action will be executed.
    private let queue: DispatchQueue

    /// The dispatch work item representing the scheduled job.
    private var workItem: DispatchWorkItem?

    // MARK: - Initialization

    /// Initializes a new `Debouncer` instance with the specified delay and queue.
    ///
    /// - Parameters:
    ///   - delay: The time interval (in seconds) to wait before executing the action.
    ///   - queue: The `DispatchQueue` on which the action should be executed. Defaults to the main queue.
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    // MARK: - Methods

    /// Schedules a closure to be executed after the specified delay. If this method is called again
    /// before the delay has passed, the previous closure will be cancelled and the timer will be reset.
    ///
    /// - Parameter action: The closure to be executed after the delay.
    func debounce(_ action: @escaping () -> Void) {
        // Cancel any existing work item
        workItem?.cancel()

        // Create a new work item
        workItem = DispatchWorkItem(block: action)

        // Schedule the new work item after the delay
        if let workItem {
            queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    /// Cancels the scheduled action.
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
