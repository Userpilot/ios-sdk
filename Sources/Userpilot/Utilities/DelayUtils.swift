//
//  DelayUtils.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 26/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Provides utility methods for delaying the execution of actions with support for
//  task cancellation. Useful for debouncing or scheduling delayed operations.
//

import Foundation

internal class DelayUtils {

    // A reference to the ongoing delay task
    private static var delayTask: DispatchWorkItem?

    /**
     * Delays an action for a specified amount of time.
     *
     * @param delayInSeconds The delay in seconds before executing the action.
     * @param action The action to execute after the delay.
     */
    static func delayAction(delayInSeconds: TimeInterval, action: @escaping () -> Void) {
        // Cancel any previous delay task
        delayTask?.cancel()

        // Create a new delay task
        delayTask = DispatchWorkItem {
            action()
        }

        // Execute the task after the specified delay
        if let delayTask = delayTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds, execute: delayTask)
        }
    }

    /**
     * Cancels any ongoing delay.
     */
    static func cancelDelay() {
        delayTask?.cancel()
    }

    static func hasPendingContent() -> Bool {
        return delayTask != nil
    }
}
