//
//  Throttle.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// Throttle to handle throttling logic
//

import Foundation

class Throttle {

    // MARK: - Properties
    private var workItem: DispatchWorkItem = DispatchWorkItem(block: { })
    private var previousRun: Date = Date.distantPast
    private let queue: DispatchQueue
    private let delay: TimeInterval

    // MARK: - init
    init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue(label: "userpilot-throttle-queue")) {
        self.delay = minimumDelay
        self.queue = queue
    }

}

// MARK: - Helper method
extension Throttle {

    func excute(_ block: @escaping () -> Void) {
        workItem.cancel()

        workItem = DispatchWorkItem { [weak self] in
            self?.previousRun = Date()
            block()
        }

        let deltaDelay = previousRun.timeIntervalSinceNow > delay ? 0 : delay
        queue.asyncAfter(deadline: .now() + Double(deltaDelay), execute: workItem)
    }

}
