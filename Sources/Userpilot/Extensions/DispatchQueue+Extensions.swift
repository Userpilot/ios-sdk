//
//  QueueType.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `QueueType` defines different queue types for dispatching tasks asynchronously.
//  It provides queues for main, background, low, and high priority tasks.
//

import Foundation

/*
QoS Priority Levels (highest to lowest):
.userInteractive - User is actively waiting, UI updates, animations
.userInitiated - User requested action, but can wait briefly
.default - General work
.utility - Long-running tasks, can take minutes
.background - Not visible to user, can take hours
*/

internal enum QueueType {
    case main
    case background
    case lowPriority
    case highPriority

    var queue: DispatchQueue {
        switch self {
        case .main:
            return DispatchQueue.main
        case .background:
            return DispatchQueue(label: Constants.DispatchQueues.background,
                                 qos: .background,
                                 target: nil)
        case .lowPriority:
            return DispatchQueue.global(qos: .utility)
        case .highPriority:
            return DispatchQueue.global(qos: .userInitiated)
        }
    }
}

internal func performOn(_ queueType: QueueType, closure: @escaping () -> Void) {
    queueType.queue.async(execute: closure)
}
