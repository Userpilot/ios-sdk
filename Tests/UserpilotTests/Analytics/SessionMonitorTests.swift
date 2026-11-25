//
//  SessionMonitorTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class SessionMonitorTests: XCTestCase {

    var monitor: SessionMonitor!
    var userpilot: MockUserpilot!
    private var center: NotificationCenter!
    private var lifecycle: LifecycleMonitor!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        userpilot = MockUserpilot.make(config: config)
        center = NotificationCenter()
        lifecycle = LifecycleMonitor(notificationCenter: center, applicationState: { .inactive })
        userpilot.container.register(LifecycleMonitoring.self, value: lifecycle)
        monitor = SessionMonitor(container: userpilot.container)
    }

    override func tearDown() {
        monitor.reset()
        monitor = nil
        userpilot = nil
        super.tearDown()
    }

    func testDidEnterBackground_shouldTrackSessionDateAndFlush() {
        // Arrange
        var trackedFlushEvent = 0
        userpilot.analyticsPublisher.onFlush = { trackedFlushEvent += 1 }

        // Act
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        // Assert
        XCTAssertFalse(monitor.isAppActive, "App should be marked inactive in background")
        XCTAssertNotNil(userpilot.storage.sessionDate, "Session date should be stored when going to background")
        XCTAssertEqual(trackedFlushEvent, 1, "Flush should be called exactly once")
    }

    func testDidBecomeActive_shouldResumeAnalytics() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }

        // Act
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Assert
        XCTAssertTrue(monitor.isAppActive, "App should be marked active when becoming active")
        XCTAssertEqual(trackedResumeEvent, 1, "Resume should be called exactly once")
    }

    func testDidBecomeActive_forEveryActivation_shouldResumeEachTime() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }

        // Act — cold start, then a background round trip
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Assert
        XCTAssertTrue(monitor.isAppActive, "App should be active again after the second activation")
        XCTAssertEqual(trackedResumeEvent, 2, "Resume should run on every activation, not only the first")
    }

    func testInit_shouldResumeOnce_WhenActivationNotificationArrives() {
        monitor.reset()
        monitor = nil
        var resumeCount = 0
        userpilot.analyticsPublisher.onResume = { resumeCount += 1 }
        monitor = SessionMonitor(container: userpilot.container)

        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let initialized = expectation(description: "init catch-up completed")
        DispatchQueue.main.async { initialized.fulfill() }
        wait(for: [initialized], timeout: 1.0)

        XCTAssertEqual(resumeCount, 1, "Init catch-up and the activation must start one session")
        XCTAssertTrue(monitor.isAppActive)
    }

    func testReset_shouldRemoveNotificationObservers() {
        // Arrange
        let setupExpectation = expectation(description: "Setup complete")
        DispatchQueue.main.async { setupExpectation.fulfill() }
        wait(for: [setupExpectation], timeout: 1.0)

        // Act
        monitor.reset()

        // Assert
        let resumeExpectation = expectation(description: "Resume should NOT be called after reset")
        resumeExpectation.isInverted = true
        userpilot.analyticsPublisher.onResume = { resumeExpectation.fulfill() }

        let flushExpectation = expectation(description: "Flush should NOT be called after reset")
        flushExpectation.isInverted = true
        userpilot.analyticsPublisher.onFlush = { flushExpectation.fulfill() }

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        wait(for: [resumeExpectation, flushExpectation], timeout: 1.0)
    }

    func testIsAppActive_flagShouldChangeOnStateChange() {
        // Assert
        XCTAssertTrue(monitor.isAppActive, "App should be active initially")

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(monitor.isAppActive, "App should be inactive after background event")

        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(monitor.isAppActive, "App should be active again after becoming active")
    }

    func testSessionDate_shouldBeClearedOnReset() {
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertNotNil(userpilot.storage.sessionDate, "Session date should be set when entering background")

        monitor.reset()
        XCTAssertNil(userpilot.storage.sessionDate, "Session date should be cleared after reset")
    }

}
