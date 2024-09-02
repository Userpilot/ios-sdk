//
//  ReadWriteLock.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 19/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// ReadWriteLock to handle thread safe logic
//

import Foundation

class ReadWriteLock {

    private let concurrentQueue: DispatchQueue

    init(label: String) {
        concurrentQueue = DispatchQueue(label: label,
                                        qos: .utility,
                                        attributes: .concurrent,
                                        autoreleaseFrequency: .workItem)
    }

    func read(closure: () -> Void) {
        concurrentQueue.sync {
            closure()
        }
    }

    func write(closure: () -> Void) {
        concurrentQueue.sync(flags: .barrier, execute: {
            closure()
        })
    }

}
