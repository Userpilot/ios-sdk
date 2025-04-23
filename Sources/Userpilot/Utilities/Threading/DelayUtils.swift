//
//  DelayUtils.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 27/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  A utility class for scheduling delayed execution of actions.
//  Provides functionality to delay a task, cancel it if needed, and check for pending execution.
//

import Foundation

/// A utility class for managing delayed execution of tasks using `DispatchWorkItem`.
/// Supports scheduling an action with a delay, canceling ongoing delays, and checking for pending tasks.
internal class DelayUtils {

    // MARK: - Properties

    /// Stores the currently scheduled delay task, if any.
    private var delayTask: DispatchWorkItem?

    // MARK: - Methods

    /**
     * Schedules an action to be executed after a specified delay.
     * If a previous task exists, it is canceled before scheduling a new one.
     *
     * - Parameters:
     *   - delayTime: The delay duration in seconds before executing the action. Defaults to `0.5` seconds.
     *   - action: The closure to execute after the delay.
     */
    func delayAction(delayTime: TimeInterval = ThemeHandler.DefaultValues.delayTimeForExperience,
                     action: @escaping () -> Void) {
        // Cancel any previously scheduled delay task before setting a new one.
        cancelDelay()

        // Create a new delay task.
        delayTask = DispatchWorkItem { action() }

        // Schedule the task after the specified delay.
        if let delayTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: delayTask)
        }
    }

    /**
     * Cancels any currently scheduled delay task, if present.
     */
    func cancelDelay() {
        delayTask?.cancel()
        delayTask = nil
    }

    /**
     * Checks if there is an active delay task that has not yet been executed.
     *
     * - Returns: `true` if a delay task is pending execution, `false` otherwise.
     */
    func hasPendingContent() -> Bool {
        return delayTask != nil
    }
}
