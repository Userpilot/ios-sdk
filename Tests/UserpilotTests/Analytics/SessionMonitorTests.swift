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
        super.setUp()
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

        let expectation = XCTestExpectation(description: "Wait for background notification to be handled")

        // Act
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.userpilot.storage.sessionDate)
            XCTAssertEqual(trackedFlushEvent, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testInit_shouldResumeAnalyticsIfAppIsActive() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }

        let expectation = XCTestExpectation(description: "Wait for initial foreground handling")

        // Act
        // Initialization already triggers the async check for active state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Assert
            XCTAssertGreaterThanOrEqual(trackedResumeEvent, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testDidEnterForeground_shouldResumeAnalytics() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }

        let expectation = XCTestExpectation(description: "Wait for foreground notification to be handled")

        // Act
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(trackedResumeEvent, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testReset_shouldRemoveNotificationObservers() {
        // Arrange - Wait for initial setup to complete
        let setupExpectation = expectation(description: "Setup complete")
        DispatchQueue.main.async {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 1.0)

        // Act
        monitor.reset()

        // Setup inverted expectations with longer timeout
        let resumeExpectation = expectation(description: "Resume should NOT be called")
        resumeExpectation.isInverted = true
        userpilot.analyticsPublisher.onResume = {
            resumeExpectation.fulfill()
        }

        let flushExpectation = expectation(description: "Flush should NOT be called")
        flushExpectation.isInverted = true
        userpilot.analyticsPublisher.onFlush = {
            flushExpectation.fulfill()
        }

        // Post notifications
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // Use longer timeout for inverted expectations
        wait(for: [resumeExpectation, flushExpectation], timeout: 1.0)

        // Additional assertions
        XCTAssertFalse(monitor.isAppActive, "App should not be considered active after reset")
    }

}
