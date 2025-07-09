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

    func testStart_shouldTrackSessionDateAndFlush_OnDidEnterBackground() {
        // Arrange
        var trackedFlushEvent = 0
        userpilot.analyticsPublisher.onFlush = { trackedFlushEvent += 1 }
        
        let expectation = XCTestExpectation(description: "Wait for background notification to be handled")

        // Act
        monitor.start()

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.userpilot.storage.sessionDate)
            XCTAssertEqual(trackedFlushEvent, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testStart_shouldResumeAnalytics_OnWillEnterForeground() {
        // Arrange
        var trackedResumeEvent = 0
        userpilot.analyticsPublisher.onResume = { trackedResumeEvent += 1 }
        
        let expectation = XCTestExpectation(description: "Wait for foreground notification to be handled")

        // Act
        monitor.start()

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(trackedResumeEvent, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testReset_shouldRemoveNotificationObservers() {
        var didTrackedFlushEvent = false
        userpilot.analyticsPublisher.onFlush = { didTrackedFlushEvent = true }
        
        var didTrackedResumeEvent = false
        userpilot.analyticsPublisher.onResume = { didTrackedResumeEvent = true }
        
        // Act
        monitor.start()
        monitor.reset()

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // Assert
        // Wait a bit to ensure no calls were triggered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(self.userpilot.storage.sessionDate)
            XCTAssertFalse(didTrackedFlushEvent)
            XCTAssertFalse(didTrackedResumeEvent)
        }
    }
}
