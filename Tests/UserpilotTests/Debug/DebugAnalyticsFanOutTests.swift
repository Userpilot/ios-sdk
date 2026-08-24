//
//  DebugAnalyticsFanOutTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugAnalyticsFanOutTests: XCTestCase {

    func testPublish_emitsToDebuggerBeforeSessionGate() {
        let config = Userpilot.Config(token: "NX-FANOUT").defaultInstance(false)
        let userpilot = MockUserpilot(config: config)
        userpilot.sessionMonitor.isAppActive = false
        userpilot.debugEventStore.start()
        let publisher = AnalyticsPublisher(container: userpilot.container)

        publisher.publish(Event(type: .event("offline-click"), properties: ["a": "1"]))

        let titles = userpilot.debugEventStore.events(for: .manual).map(\.title)
        XCTAssertEqual(titles, ["offline-click"])
    }

    func testPublishInternalSDKEvent_emitsToDebuggerBeforeCanRequestGate() {
        let config = Userpilot.Config(token: "NX-FANOUT-INT").defaultInstance(false)
        let userpilot = MockUserpilot(config: config)
        userpilot.debugEventStore.start()
        let publisher = AnalyticsPublisher(container: userpilot.container)

        publisher.publishInternalSDKEvent(
            ExperienceFlowSeenEvent(flowId: 7),
            socketSubscription: nil
        )

        let titles = userpilot.debugEventStore.events(for: .internalSDK).map(\.title)
        XCTAssertEqual(titles, [SDKEventsName.flowExperienceSeen.rawValue])
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
