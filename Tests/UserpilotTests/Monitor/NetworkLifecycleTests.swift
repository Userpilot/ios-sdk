//
//  NetworkLifecycleTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies connectivity and analytics ordering through the shared lifecycle monitor.
//

import UIKit
import XCTest
@testable import Userpilot

final class NetworkLifecycleTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var center: NotificationCenter!
    private var lifecycle: LifecycleMonitor!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot.make(config: Userpilot.Config(token: UUID().uuidString).defaultInstance(false))
        center = NotificationCenter()
        lifecycle = LifecycleMonitor(notificationCenter: center, applicationState: { .inactive })
        userpilot.container.register(LifecycleMonitoring.self, value: lifecycle)
    }

    override func tearDown() {
        userpilot = nil
        lifecycle = nil
        center = nil
        super.tearDown()
    }

    func testForeground_refreshesConnectivityBeforeAnalytics_andPublishesAppStateFirst() {
        let network = makeNetwork(for: userpilot)
        let session = SessionMonitor(container: userpilot.container)
        var calls: [String] = []
        network.onStart = { [weak session] in
            XCTAssertEqual(session?.isAppActive, true)
            calls.append("network")
        }
        userpilot.analyticsPublisher.onResume = { calls.append("analytics") }

        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(calls, ["network", "analytics"])
        withExtendedLifetime((network, session)) {}
    }

    func testBackground_stopsNetworkBeforeFlush_andReturnResumesBoth() {
        let network = makeNetwork(for: userpilot)
        let session = SessionMonitor(container: userpilot.container)
        var calls: [String] = []
        let storage = userpilot.storage
        network.onStop = { [weak session] in
            XCTAssertEqual(session?.isAppActive, false)
            XCTAssertNotNil(storage.sessionDate)
            calls.append("stop")
        }
        network.onStart = { calls.append("start") }
        userpilot.analyticsPublisher.onFlush = { calls.append("flush") }
        userpilot.analyticsPublisher.onResume = { calls.append("resume") }

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(calls, ["stop", "flush", "start", "resume"])
        XCTAssertNotNil(userpilot.storage.sessionDate)
        // Deinit also stops resources; the lifecycle-state assertion applies only to background delivery.
        network.onStop = nil
        withExtendedLifetime((network, session)) {}
    }

    func testAlreadyActiveStartup_startsNetworkBeforeResumingAnalytics() {
        lifecycle = LifecycleMonitor(notificationCenter: center, applicationState: { .active })
        userpilot.container.register(LifecycleMonitoring.self, value: lifecycle)
        // Only SessionMonitor replays activation; it controls both calls synchronously.
        let network = makeNetwork(for: userpilot)
        let session = SessionMonitor(container: userpilot.container)
        var calls: [String] = []
        network.onStart = { calls.append("network") }
        userpilot.analyticsPublisher.onResume = { calls.append("analytics") }
        XCTAssertTrue(calls.isEmpty)
        drainMainQueue()
        XCTAssertEqual(calls, ["network", "analytics"])
        withExtendedLifetime((network, session)) {}
    }

    func testRetiringOneSession_keepsOtherInstanceSubscribed() {
        let firstNetwork = makeNetwork(for: userpilot)
        weak var retired: SessionMonitor?
        var firstStarts = 0
        firstNetwork.onStart = { firstStarts += 1 }
        let secondOwner = MockUserpilot.make(config: Userpilot.Config(token: UUID().uuidString).defaultInstance(false))
        secondOwner.container.register(LifecycleMonitoring.self, value: lifecycle)
        let secondNetwork = makeNetwork(for: secondOwner)
        var secondStarts = 0
        secondNetwork.onStart = { secondStarts += 1 }
        // Drain temporary Objective-C references before checking the weak subscriber's lifetime.
        let second = autoreleasepool {
            let first = SessionMonitor(container: userpilot.container)
            retired = first
            let second = SessionMonitor(container: secondOwner.container)
            withExtendedLifetime(first) {}
            return second
        }

        drainMainQueue()
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertNil(retired)
        XCTAssertEqual(firstStarts, 0)
        XCTAssertEqual(secondStarts, 1)
        withExtendedLifetime((secondOwner, second)) {}
    }

    func testNetworkConstruction_doesNotSubscribeToLifecycle() {
        let network = makeNetwork(for: userpilot)
        var starts = 0
        network.onStart = { starts += 1 }
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        drainMainQueue()
        XCTAssertEqual(starts, 0)
    }

    private func makeNetwork(for owner: MockUserpilot) -> RecordingNetworkMonitor {
        let network = RecordingNetworkMonitor(container: owner.container)
        owner.container.register(NetworkMonitoring.self, value: network)
        return network
    }

    private func drainMainQueue() {
        let drained = expectation(description: "lifecycle replay completed")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

/// Replaces native connectivity only; SessionMonitor owns the real lifecycle subscription and ordering.
private final class RecordingNetworkMonitor: NetworkMonitor {
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    override func startMonitoring() { onStart?() }
    override func stopMonitoring() { onStop?() }
}
