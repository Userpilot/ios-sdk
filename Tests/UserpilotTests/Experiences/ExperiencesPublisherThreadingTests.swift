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

    func testDeepLinkForwardsToLinkOpenerOnMain() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let forwarded = expectation(description: "deep link forwarded")
        userpilot.linkOpener.onHandleURL = { received in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(received, url)
            forwarded.fulfill()
        }
        publisher.triggerDeepLink(url: url)
        wait(for: [forwarded], timeout: 2)
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
