//
//  File.swift
//  
//
//  Created by Motasem Hamed on 30/09/2024.
//

import Foundation

internal  enum QueueType {
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
            return DispatchQueue.global(qos: .userInitiated)
        case .highPriority:
            return DispatchQueue.global(qos: .userInitiated)
        }
    }
}

internal func performOn(_ queueType: QueueType, closure: @escaping () -> Void) {
    queueType.queue.async(execute: closure)
}
