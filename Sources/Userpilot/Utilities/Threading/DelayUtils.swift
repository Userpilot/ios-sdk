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

/// Safe to schedule, cancel, or check pending work from any thread. Actions run on main.
/// State changes are synchronous; cancellation cannot stop an action already claimed for execution.
internal class DelayUtils {

    private let lock = NSLock()
    private var pendingTask: (id: UUID, workItem: DispatchWorkItem)?

    /// Schedules an action on main, replacing any task still pending. The default delay is 0.5 seconds.
    func delayAction(delayTime: TimeInterval = 0.5, action: @escaping () -> Void) {
        let taskID = UUID()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let shouldRun = self.lock.withLock {
                // An old callback must not consume a replacement task.
                guard self.pendingTask?.id == taskID else { return false }
                self.pendingTask = nil
                return true
            }
            guard shouldRun else { return }
            action()
        }

        lock.withLock {
            pendingTask?.workItem.cancel()
            pendingTask = (taskID, workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: workItem)
        }
    }

    /// Schedules an independent action on main; replacement and `cancelDelay()` do not affect it.
    func delayActionWithoutCancel(delayTime: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: action)
    }

    /// Cancels the pending task immediately. An action already claimed for execution may finish.
    func cancelDelay() {
        lock.withLock {
            pendingTask?.workItem.cancel()
            pendingTask = nil
        }
    }

    /// Returns whether a task is waiting to run; clears before its action is called.
    func hasPendingAction() -> Bool {
        lock.withLock {
            pendingTask != nil
        }
    }

    /// Schedules an action with the default delay of 0.5 seconds.
    func delayAction(action: @escaping () -> Void) {
        delayAction(delayTime: 0.5, action: action)
    }
}
