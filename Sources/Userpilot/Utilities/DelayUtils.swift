//
//  DelayUtils.swift
//  Userpilot
//
//  Created by Motasem Hamed on 26/01/2025.
//

import Foundation

class DelayUtils {

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
