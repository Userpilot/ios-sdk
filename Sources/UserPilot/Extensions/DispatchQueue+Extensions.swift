//
//  QueueType.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 13/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `QueueType` defines different queue types for dispatching tasks asynchronously.
//  It provides queues for main, background, low, and high priority tasks.
//

import Foundation

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
            return DispatchQueue(label: "com.app.queue",
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
