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

    /// A delegate that reaches back into the multicast from inside its own callback — the shape of
    /// `AnalyticsPublisher` resolving a lazily-built subscriber while a socket callback is being
    /// dispatched, which registers it on the socket thread mid-`invoke`.
    private final class ReentrantDelegate {
        var calls = 0
        var onCall: (() -> Void)?
    }

    func testInvokeLetsADelegateRegisterAnotherFromItsOwnCallback() {
        let multicast = MulticastDelegate<ReentrantDelegate>()
        let first = ReentrantDelegate()
        let late = ReentrantDelegate()
        multicast.add(first)
        first.onCall = { multicast.add(late) }

        // Hangs if callbacks are dispatched while the lock is held (NSLock is not recursive),
        // and would mutate mid-iteration if the walk used the live table instead of a snapshot.
        multicast.invoke { $0.calls += 1; $0.onCall?() }

        // The late registration lands, but not in the pass that was already snapshotted.
        XCTAssertEqual(first.calls, 1)
        XCTAssertEqual(late.calls, 0)

        multicast.invoke { $0.calls += 1; $0.onCall?() }

        XCTAssertEqual(first.calls, 2)
        XCTAssertEqual(late.calls, 1)
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
