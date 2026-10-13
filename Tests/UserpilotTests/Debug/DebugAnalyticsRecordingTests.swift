//
//  DebugAnalyticsRecordingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugAnalyticsRecordingTests: XCTestCase {

    func testPublish_recordsInDebuggerBeforeSessionGate() {
        let config = Userpilot.Config(token: "NX-FANOUT").defaultInstance(false)
        let userpilot = MockUserpilot(config: config)
        userpilot.sessionMonitor.isAppActive = false
        userpilot.debugEventStore.start()
        let publisher = AnalyticsPublisher(container: userpilot.container)

        publisher.publish(Event(type: .event("offline-click"), properties: ["a": "1"]))

        let titles = userpilot.debugEventStore.events(for: .manual).map(\.title)
        XCTAssertEqual(titles, ["offline-click"])
    }

    func testPublishInternalSDKEvent_recordsInDebuggerBeforeCanRequestGate() {
        let config = Userpilot.Config(token: "NX-FANOUT-INT").defaultInstance(false)
        let userpilot = MockUserpilot(config: config)
        userpilot.debugEventStore.start()
        let publisher = AnalyticsPublisher(container: userpilot.container)

        publisher.publishInternalSDKEvent(
            ExperienceFlowSeenEvent(flowId: 7)
        )

        let titles = userpilot.debugEventStore.events(for: .internalSDK).map(\.title)
        XCTAssertEqual(titles, [SDKEventsName.flowExperienceSeen.rawValue])
    }

    func testPublisher_keepsDebuggerEventsInsideTheirInstance() {
        let first = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-A").defaultInstance(false))
        let second = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-B").defaultInstance(false))
        first.container.register(
            UserpilotDebuggerManaging.self, value: UserpilotDebuggerManager(container: first.container)
        )
        first.sessionMonitor.isAppActive = false
        second.sessionMonitor.isAppActive = false
        first.debugEventStore.start()
        second.debugEventStore.start()
        let firstPublisher = AnalyticsPublisher(container: first.container)
        let secondPublisher = AnalyticsPublisher(container: second.container)

        firstPublisher.publish(Event(type: .event("first")))
        secondPublisher.publish(Event(type: .event("second")))
        first.logout()

        XCTAssertTrue(first.debugEventStore.events(for: .manual).isEmpty)
        XCTAssertEqual(second.debugEventStore.events(for: .manual).map(\.title), ["second"])
        XCTAssertEqual(second.debuggerManager.resetCount, 0)
    }

    func testCreateUserpilot_resolvesDebuggerManager() {
        let userpilot = Userpilot(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        )
        let manager = userpilot.container.resolve(UserpilotDebuggerManaging.self)
        XCTAssertTrue(manager is UserpilotDebuggerManager)
    }
}

// swiftlint:enable all
