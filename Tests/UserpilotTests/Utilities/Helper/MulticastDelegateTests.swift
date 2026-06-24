//
//  MulticastDelegateTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class MulticastDelegateTests: XCTestCase {

    private final class Delegate {
        var calls = 0
    }

    func testAddInvokeAndRemoveDelegates() {
        let multicast = MulticastDelegate<Delegate>()
        let first = Delegate()
        let second = Delegate()

        multicast.add(first)
        multicast.add(first)
        multicast.add(second)
        multicast.invoke { $0.calls += 1 }

        XCTAssertEqual(first.calls, 1)
        XCTAssertEqual(second.calls, 1)

        multicast.remove(first)
        multicast.invoke { $0.calls += 1 }

        XCTAssertEqual(first.calls, 1)
        XCTAssertEqual(second.calls, 2)
    }

    func testMulticastDoesNotRetainDelegates() {
        let multicast = MulticastDelegate<Delegate>()
        var delegate: Delegate? = Delegate()
        let weakDelegate = WeakBox(delegate)

        multicast.add(delegate!)
        delegate = nil
        multicast.invoke { $0.calls += 1 }

        XCTAssertNil(weakDelegate.value)
    }
}

private final class WeakBox<T: AnyObject> {
    weak var value: T?

    init(_ value: T?) {
        self.value = value
    }
}
