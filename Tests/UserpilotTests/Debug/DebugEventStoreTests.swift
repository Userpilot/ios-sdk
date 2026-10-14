//
//  DebugEventStoreTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class DebugEventStoreTests: XCTestCase {

    func testRecordingIsOptInAndRepeatedStartDoesNotDuplicateEvents() {
        let store = DebugEventStore()
        store.record(track("before"))
        XCTAssertTrue(store.events(for: .manual).isEmpty)
        store.start()
        store.start()
        store.record(track("during"))
        store.stop()
        store.record(track("after"))
        XCTAssertEqual(store.events(for: .manual).map(\.title), ["during"])
    }

    func testBurstKeepsExactlyTheNewestFiftyEventsWithoutACollector() {
        let store = DebugEventStore()
        store.start()
        for index in 0..<250 { store.record(track("e\(index)")) }
        XCTAssertEqual(store.events(for: .manual).map(\.title), (200..<250).reversed().map { "e\($0)" })
    }

    func testResetClearsAllChannelsAndAllowsNewEvents() {
        let store = DebugEventStore()
        store.start()
        store.record(track("old"))
        store.record(Event(type: .autoCaptureEvent, interactionEventName: "tap"))
        store.record(FlowExperienceActionEvent.seen(flowId: 1))
        store.reset()
        XCTAssertTrue(DebugEventChannel.allCases.allSatisfy { store.events(for: $0).isEmpty })
        store.record(track("new"))
        XCTAssertEqual(store.events(for: .manual).map(\.title), ["new"])
    }

    func testResetOnlyChangesItsOwnInstance() {
        let first = DebugEventStore()
        let second = DebugEventStore()
        first.start()
        second.start()
        first.record(track("first"))
        second.record(track("second"))
        first.reset()
        XCTAssertTrue(first.events(for: .manual).isEmpty)
        XCTAssertEqual(second.events(for: .manual).map(\.title), ["second"])
    }

    func testDelayedUIReadsTheLatestStateAfterReset() {
        let store = DebugEventStore()
        store.start()
        var pendingReads: [() -> Void] = []
        var displayed: [DebugEvent] = []
        let token = store.observe(.manual) {
            pendingReads.append { displayed = store.events(for: .manual) }
        }
        store.record(track("old"))
        store.reset()
        // Even an earlier invalidation delivered last cannot resurrect the old row.
        pendingReads.reversed().forEach { $0() }
        XCTAssertTrue(displayed.isEmpty)
        store.removeObserver(token)
    }

    func testConcurrentRecordingKeepsUniqueOrderedIDsAndBoundedHistory() {
        let store = DebugEventStore()
        store.start()
        DispatchQueue.concurrentPerform(iterations: 250) { index in
            store.record(Event(type: .event("e\(index)")))
        }
        let ids = store.events(for: .manual).map(\.id)
        XCTAssertEqual(ids, Array((201...250).reversed()))
    }

    private func track(_ name: String) -> Event { Event(type: .event(name)) }
}
