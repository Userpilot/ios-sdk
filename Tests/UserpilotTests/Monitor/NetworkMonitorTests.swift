//
//  NetworkMonitorTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

/// Collects `networkMonitorDidUpdate` calls off whichever queue the monitor notifies on.
private final class SpyNetworkDelegate: NetworkMonitoringDelegate {
    private let lock = NSLock()
    private var _updates: [(isReady: Bool, isNetworkAvailable: Bool)] = []

    var updates: [(isReady: Bool, isNetworkAvailable: Bool)] {
        lock.lock()
        defer { lock.unlock() }
        return _updates
    }

    /// Fulfilled the first time the monitor reports available internet.
    var onAvailable: (() -> Void)?

    func networkMonitorDidUpdate(isReady: Bool, isNetworkAvailable: Bool) {
        lock.lock()
        _updates.append((isReady, isNetworkAvailable))
        lock.unlock()

        if isReady && isNetworkAvailable {
            onAvailable?()
        }
    }
}

/// Counts probes across queues.
private final class ProbeCounter {
    private let lock = NSLock()
    private var count = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

final class NetworkMonitorTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var monitor: NetworkMonitor!
    private var delegateSpy: SpyNetworkDelegate!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        config.logger = MockLogger()
        userpilot = MockUserpilot(config: config)

        monitor = NetworkMonitor(container: userpilot.container)
        // Collapse the interface debounce so the tests exercise ordering, not wall-clock.
        monitor.debounceDelay = 0.01

        delegateSpy = SpyNetworkDelegate()
        monitor.delegate = delegateSpy
    }

    override func tearDown() {
        monitor.stopMonitoring()
        monitor = nil
        delegateSpy = nil
        userpilot = nil
        super.tearDown()
    }

    /// A probe that fails a fixed number of times and succeeds afterwards, counting calls.
    private func installProbe(failuresBeforeSuccess: Int, counter: ProbeCounter) {
        monitor.reachabilityProbe = { _, completion in
            let attempt = counter.increment()
            completion(attempt > failuresBeforeSuccess)
        }
    }

    /// Brings the interface up and settles the first (failing) probe.
    private func arrangeOfflineOnALiveInterface(counter: ProbeCounter) {
        monitor.updateInterfaceState(hasInterface: true, connectionType: .wifi)
        // The interface debounce plus the probe are both async.
        let settled = expectation(description: "first probe settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertGreaterThanOrEqual(counter.value, 1, "precondition: the first probe ran")
        XCTAssertFalse(monitor.isNetworkAvailable, "precondition: the monitor is offline")
    }

    // MARK: - Recovery while the interface stays connected

    /// The regression this guards: `NWPathMonitor` reports INTERFACE changes only. When a probe
    /// fails while the interface stays satisfied, nothing re-probes on its own, so the SDK stayed
    /// offline — routing every event to local storage — until the interface flapped or the app was
    /// backgrounded. Publishing an event is what drives recovery now.
    func testRecheckIfOffline_afterAFailedProbe_recoversWhenTheEndpointComesBack() {
        let counter = ProbeCounter()
        installProbe(failuresBeforeSuccess: 1, counter: counter)
        monitor.reachabilityRecheckInterval = 0
        arrangeOfflineOnALiveInterface(counter: counter)

        let recovered = expectation(description: "monitor reports internet access again")
        recovered.assertForOverFulfill = false
        delegateSpy.onAvailable = { recovered.fulfill() }

        // An event arrives while we believe we are offline.
        monitor.recheckIfOffline()

        wait(for: [recovered], timeout: 5.0)
        XCTAssertTrue(monitor.isNetworkAvailable)
    }

    /// A burst of events must not become a burst of probes.
    func testRecheckIfOffline_isThrottled_whileTheIntervalHasNotElapsed() {
        let counter = ProbeCounter()
        // Never recovers, so every allowed call would otherwise probe.
        installProbe(failuresBeforeSuccess: .max, counter: counter)
        monitor.reachabilityRecheckInterval = 60
        arrangeOfflineOnALiveInterface(counter: counter)

        let afterFirstProbe = counter.value
        for _ in 0..<20 {
            monitor.recheckIfOffline()
        }

        let settled = expectation(description: "any probes settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertEqual(
            counter.value, afterFirstProbe,
            "20 events inside the throttle window must not trigger a probe")
    }

    /// While connectivity is verified there is nothing to recover, so no probe should run.
    func testRecheckIfOffline_doesNothing_whenAlreadyOnline() {
        let counter = ProbeCounter()
        installProbe(failuresBeforeSuccess: 0, counter: counter)
        monitor.reachabilityRecheckInterval = 0

        let online = expectation(description: "monitor reports internet access")
        online.assertForOverFulfill = false
        delegateSpy.onAvailable = { online.fulfill() }
        monitor.updateInterfaceState(hasInterface: true, connectionType: .wifi)
        wait(for: [online], timeout: 5.0)

        let afterOnline = counter.value
        for _ in 0..<5 {
            monitor.recheckIfOffline()
        }

        let settled = expectation(description: "any probes settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertEqual(counter.value, afterOnline, "a verified connection must not be re-probed")
    }

    /// Without an interface there is nothing to reach through; the interface transition itself
    /// re-probes when one comes back.
    func testRecheckIfOffline_doesNothing_whileTheInterfaceIsDown() {
        let counter = ProbeCounter()
        installProbe(failuresBeforeSuccess: .max, counter: counter)
        monitor.reachabilityRecheckInterval = 0
        arrangeOfflineOnALiveInterface(counter: counter)

        monitor.updateInterfaceState(hasInterface: false, connectionType: .unknown)
        let dropped = expectation(description: "interface drop settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dropped.fulfill() }
        wait(for: [dropped], timeout: 2.0)

        let afterDrop = counter.value
        for _ in 0..<5 {
            monitor.recheckIfOffline()
        }

        let settled = expectation(description: "any probes settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertEqual(counter.value, afterDrop, "no probes should run while the interface is down")
    }
}
// swiftlint:enable all
