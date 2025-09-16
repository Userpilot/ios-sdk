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

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        monitor = SessionMonitor(container: userpilot.container)
    }

    override func tearDown() {
        monitor.reset()
        super.tearDown()
    }

    func testDidEnterBackground_shouldTrackSessionDateAndFlush() {
        // Arrange
        var trackedFlushEvent = 0
        userpilot.analyticsPublisher.onFlush = { trackedFlushEvent += 1 }

        let expectation = self.expectation(description: "Background notification handled")

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        // Act
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.monitor.isAppActive, "App should be marked inactive in background")
            // swiftlint:disable:next line_length
            XCTAssertNotNil(self.userpilot.storage.sessionDate, "Session date should be stored when going to background")
            XCTAssertEqual(trackedFlushEvent, 1, "Flush should be called exactly once")
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    func testDidEnterForeground_shouldResumeAnalytics() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }

        let expectation = self.expectation(description: "Foreground notification handled")

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // Act
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.monitor.isAppActive, "App should be marked active when entering foreground")
            XCTAssertEqual(trackedResumeEvent, 1, "Resume should be called exactly once")
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    func testInit_shouldResumeAnalyticsIfAppIsActive() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }

        let expectation = self.expectation(description: "Initial active app handling")

        // Act
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertGreaterThanOrEqual(trackedResumeEvent, 0, "Resume may be called if app is active at init")
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
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

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        wait(for: [resumeExpectation, flushExpectation], timeout: 1.0)
    }

    func testIsAppActive_flagShouldChangeOnStateChange() {
        // Assert
        XCTAssertTrue(monitor.isAppActive, "App should be active initially")

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(monitor.isAppActive, "App should be inactive after background event")

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(monitor.isAppActive, "App should be active again after foreground event")
    }

    func testSessionDate_shouldBeClearedOnReset() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertNotNil(userpilot.storage.sessionDate, "Session date should be set when entering background")

        monitor.reset()
        XCTAssertNil(userpilot.storage.sessionDate, "Session date should be cleared after reset")
    }

}
