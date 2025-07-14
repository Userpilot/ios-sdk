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

        // Wait for the initial state handling to complete before posting the notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            
            // Assert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // The resume should be called at least once (could be 2 if initial state was active)
                XCTAssertGreaterThanOrEqual(trackedResumeEvent, 1)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testReset_shouldRemoveNotificationObservers() {
        // Arrange
        var didTrackedFlushEvent = false
        userpilot.analyticsPublisher.onFlush = { didTrackedFlushEvent = true }
        
        var didTrackedResumeEvent = false
        userpilot.analyticsPublisher.onResume = { didTrackedResumeEvent = true }
        
        let expectation = XCTestExpectation(description: "Wait for reset to complete")

        // Act
        monitor.start()
        
        // Wait for initial state handling to complete, then reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.monitor.reset()
            
            // Reset the flags after reset
            didTrackedFlushEvent = false
            didTrackedResumeEvent = false
            
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

            // Assert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertNil(self.userpilot.storage.sessionDate)
                XCTAssertFalse(didTrackedFlushEvent)
                XCTAssertFalse(didTrackedResumeEvent)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}
