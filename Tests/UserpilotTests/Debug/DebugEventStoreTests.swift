//
//  DebugEventStoreTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugEventStoreTests: XCTestCase {

    func testStart_collectsBusEventsIntoMatchingChannelBuffer() {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)

        store.start()
        bus.emit(event(id: 1, channel: .manual, title: "clicked"))
        bus.emit(event(id: 2, channel: .autoCapture, title: "tap"))

        XCTAssertEqual(store.events(for: .manual).map(\.title), ["clicked"])
        XCTAssertEqual(store.events(for: .autoCapture).map(\.title), ["tap"])
        XCTAssertTrue(store.events(for: .internalSDK).isEmpty)
    }

    func testStore_keepsNewestEventsFirstAndDropsPastTheCap() {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)
        store.start()

        let extra = 5
        for index in 0..<(DebugEventStore.maxEvents + extra) {
            bus.emit(event(id: index, title: "e\(index)"))
        }

        let titles = store.events(for: .manual).map(\.title)
        XCTAssertEqual(titles.count, DebugEventStore.maxEvents)
        XCTAssertEqual(titles.first, "e\(DebugEventStore.maxEvents + extra - 1)")
        XCTAssertEqual(titles.last, "e\(extra)")
    }

    func testReset_clearsAllChannels() {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)
        store.start()
        bus.emit(event(id: 1, title: "one"))

        store.reset()

        XCTAssertTrue(store.events(for: .manual).isEmpty)
    }

    func testEmit_isIgnoredWhenStoreIsNotStarted() {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)

        bus.emit(event(id: 1, title: "dropped"))

        XCTAssertTrue(store.events(for: .manual).isEmpty)
    }

    private func event(
        id: Int,
        channel: DebugEventChannel = .manual,
        title: String
    ) -> DebugEvent {
        DebugEvent(
            id: id,
            channel: channel,
            title: title,
            typeLabel: "track",
            timestampMs: Int64(id),
            properties: []
        )
    }
}

// swiftlint:enable all
