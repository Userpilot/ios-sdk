//
//  LifecycleMonitorTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies native lifecycle forwarding, weak subscriptions and deferred startup.
//

import UIKit
import XCTest
@testable import Userpilot

final class LifecycleMonitorTests: XCTestCase {
    private let center = NotificationCenter()

    func testDuplicateSubscription_deliversOneCallback() {
        let monitor = makeMonitor()
        let delegate = RecordingLifecycleDelegate()
        monitor.addDelegate(delegate, replayCurrentState: false)
        monitor.addDelegate(delegate, replayCurrentState: false)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(delegate.activeCount, 1)
    }

    func testRemovingOneInstance_keepsOtherInstanceSubscribed() {
        let monitor = makeMonitor()
        let first = RecordingLifecycleDelegate()
        let second = RecordingLifecycleDelegate()
        monitor.addDelegate(first, replayCurrentState: false)
        monitor.addDelegate(second, replayCurrentState: false)
        monitor.removeDelegate(first)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(first.activeCount, 0)
        XCTAssertEqual(first.backgroundCount, 0)
        XCTAssertEqual(second.activeCount, 1)
        XCTAssertEqual(second.backgroundCount, 1)
    }

    func testLateSubscription_replaysActiveStateAfterConstruction() {
        let monitor = makeMonitor(state: .active)
        let delegate = RecordingLifecycleDelegate()
        monitor.addDelegate(delegate, replayCurrentState: true)
        XCTAssertEqual(delegate.activeCount, 0)
        drainMainQueue()
        XCTAssertEqual(delegate.activeCount, 1)
    }

    func testRemovedSubscription_doesNotReceiveQueuedCatchUp() {
        let monitor = makeMonitor(state: .active)
        let delegate = RecordingLifecycleDelegate()
        monitor.addDelegate(delegate, replayCurrentState: true)
        monitor.removeDelegate(delegate)
        drainMainQueue()
        XCTAssertEqual(delegate.activeCount, 0)
    }

    func testCatchUp_rechecksApplicationStateWhenItRuns() {
        var state = UIApplication.State.active
        let monitor = LifecycleMonitor(notificationCenter: center, applicationState: { state })
        let delegate = RecordingLifecycleDelegate()
        monitor.addDelegate(delegate, replayCurrentState: true)
        state = .background
        drainMainQueue()
        XCTAssertEqual(delegate.activeCount, 0)
    }

    func testSubscriptionAndQueuedCatchUp_doNotRetainDelegate() {
        let monitor = makeMonitor(state: .active)
        var delegate: RecordingLifecycleDelegate? = RecordingLifecycleDelegate()
        weak var weakDelegate = delegate
        if let delegate { monitor.addDelegate(delegate, replayCurrentState: true) }
        delegate = nil
        XCTAssertNil(weakDelegate)
        drainMainQueue()
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func testSceneWindowAndMemoryEvents_doNotBecomeAppActivations() {
        let monitor = makeMonitor()
        let delegate = RecordingLifecycleDelegate()
        monitor.addDelegate(delegate, replayCurrentState: false)
        center.post(name: UIScene.didActivateNotification, object: nil)
        center.post(name: UIWindow.didBecomeKeyNotification, object: nil)
        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertEqual(delegate.sceneCount, 1)
        XCTAssertEqual(delegate.windowCount, 1)
        XCTAssertEqual(delegate.memoryCount, 1)
        XCTAssertEqual(delegate.activeCount, 0)
        XCTAssertEqual(delegate.backgroundCount, 0)
    }

    func testMonitorCanBeReleasedWithObserversInstalled() {
        var monitor: LifecycleMonitor? = makeMonitor()
        weak var weakMonitor = monitor
        let delegate = RecordingLifecycleDelegate()
        monitor?.addDelegate(delegate, replayCurrentState: false)
        monitor = nil
        XCTAssertNil(weakMonitor)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(delegate.activeCount, 0)
    }

    private func makeMonitor(state: UIApplication.State = .inactive) -> LifecycleMonitor {
        LifecycleMonitor(notificationCenter: center, applicationState: { state })
    }

    private func drainMainQueue() {
        let drained = expectation(description: "lifecycle catch-up completed")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

private final class RecordingLifecycleDelegate: LifecycleDelegate {
    var activeCount = 0
    var backgroundCount = 0
    var sceneCount = 0
    var windowCount = 0
    var memoryCount = 0

    func onAppActive() { activeCount += 1 }
    func onAppBackground() { backgroundCount += 1 }
    func onSceneActive() { sceneCount += 1 }
    func onWindowBecameKey() { windowCount += 1 }
    func onMemoryWarning() { memoryCount += 1 }
}
