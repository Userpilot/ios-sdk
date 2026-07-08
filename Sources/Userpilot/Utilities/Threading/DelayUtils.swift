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

internal class DelayUtils {

    /// The current work item that can be cancelled
    private var currentWorkItem: DispatchWorkItem?

    /// Queue for thread-safe operations
    private let queue = DispatchQueue(label: Constants.DispatchQueues.delayQueue, qos: .userInteractive)

    /**
     Executes an action after a specified delay.
     Any previously scheduled action will be automatically cancelled.
     
     - Parameters:
        - delayTime: The delay time in seconds before executing the action
        - action: The closure to execute after the delay
     */
    func delayAction(delayTime: TimeInterval = 0.5, action: @escaping () -> Void) {
        queue.async { [weak self] in
            // Cancel any existing delayed action
            self?.currentWorkItem?.cancel()

            // Create new work item
            let workItem = DispatchWorkItem {
                // Execute on main queue if it's UI-related work
                DispatchQueue.main.async {
                    action()
                }
            }

            // Store the work item so it can be cancelled later
            self?.currentWorkItem = workItem

            // Schedule the work item
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: workItem)
        }
    }

    /**
     Executes an action after a specified delay without cancelling previous actions.
     
     - Parameters:
        - delayTime: The delay time in seconds before executing the action
        - action: The closure to execute after the delay
     */
    func delayActionWithoutCancel(delayTime: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
            action()
        }
    }

    /**
     Cancels any currently scheduled delayed action.
     */
    func cancelDelay() {
        if !hasPendingAction() { return }
        queue.async { [weak self] in
            self?.currentWorkItem?.cancel()
            self?.currentWorkItem = nil
        }
    }

    /**
     Checks if there's a currently scheduled action that hasn't been executed yet.
    
     - Returns: `true` if there's a pending action, `false` otherwise
     */
    func hasPendingAction() -> Bool {
        return currentWorkItem != nil && currentWorkItem?.isCancelled == false
    }

    /**
     Executes an action with a default delay of 0.5 seconds.
     
     - Parameter action: The closure to execute after the delay
     */
    func delayAction(action: @escaping () -> Void) {
        delayAction(delayTime: 0.5, action: action)
    }
}
