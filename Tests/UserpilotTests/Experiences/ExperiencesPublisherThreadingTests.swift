//
//  ExperiencesPublisherThreadingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Preserves host callback and off-main logout coverage across the publisher refactor.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {
    func testConcurrentManualRequestsReserveOnlyOneOperation() {
        let publisher = self.publisher!
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            publisher.triggerExperience("flow-\(index)")
        }
        publisher.mockWaitForQueue()
        XCTAssertEqual(userpilot.analyticsPublisher.requests.count, 1)
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

    func testLogoutFromBackgroundDoesNotConstructOverlay() {
        restoreFacadeOwner()
        XCTAssertNil(userpilot.existingExperienceOverlayWindow)
        logoutOnBackground()
        XCTAssertNil(userpilot.existingExperienceOverlayWindow)
    }

    func testLogoutFromBackgroundHidesAlreadyExistingIdleOverlay() {
        restoreFacadeOwner()
        let overlay = userpilot.experienceOverlayWindow
        overlay.prepareForPresentation()
        XCTAssertFalse(overlay.isHidden)
        logoutOnBackground()
        XCTAssertTrue(overlay.isHidden)
    }

    func testLogoutBeforeQueuedClosePreservesItsDismissalWaiter() {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        var completions = 0
        publisher.mockWaitForQueue {
            publisher.endExperience(manualClose: true) {
                XCTAssertTrue(Thread.isMainThread)
                completions += 1
            }
            publisher.logout()
        }
        settle()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
    }

    func testDismissalWaiterCompletesWhenNoExperienceExists() {
        let completed = expectation(description: "idle dismissal completed")
        publisher.endExperience(manualClose: true) {
            XCTAssertTrue(Thread.isMainThread)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    private func restoreFacadeOwner() {
        userpilot.container.owner = userpilot
        publisher = ExperiencesPublisher(container: userpilot.container)
        userpilot.container.register(ExperiencesPublishing.self, value: publisher!)
    }

    private func logoutOnBackground() {
        let loggedOut = expectation(description: "background logout returned")
        let publisher = self.publisher!
        DispatchQueue.global(qos: .userInitiated).async {
            publisher.logout()
            loggedOut.fulfill()
        }
        wait(for: [loggedOut], timeout: 2)
        settle()
    }
}
