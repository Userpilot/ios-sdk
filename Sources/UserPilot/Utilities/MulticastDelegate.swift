//
//  MulticastDelegate.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// MulticastDelegate to handle multicasting logic
//

import Foundation

@propertyWrapper
struct Multicast<T> {

    // MARK: - Properties
    private var _wrappedValue: MulticastDelegate<T> = .init()
    var projectedValue: MulticastDelegate<T> { _wrappedValue }

    var wrappedValue: T {
        get { fatalError("Should not be accessed directly") }
        set { _wrappedValue.add(newValue) }
    }

    // MARK: - init
    init() {}

}

final class MulticastDelegate<T> {

    // MARK: - Properties
    private let delegates: NSHashTable<AnyObject> = NSHashTable.weakObjects()

}

// MARK: - Helper methods
extension MulticastDelegate {

    func add(_ delegate: T) {
        delegates.add(delegate as AnyObject)
    }

    func remove(_ delegateToRemove: T) {
        for delegate in delegates.allObjects.reversed() where delegate === delegateToRemove as AnyObject {
            delegates.remove(delegate)
        }
    }

    func invoke(_ invocation: (T) -> Void) {
        // swiftlint:disable force_cast
        for delegate in delegates.allObjects.reversed() {
            invocation(delegate as! T)
        }
        // swiftlint:enable force_cast
    }

}
