//
//  AppReviewManagerTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 14/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies main-thread delivery and lifecycle checks without opening StoreKit UI.
//

import XCTest
@testable import Userpilot

final class AppReviewManagerTests: XCTestCase {
    func testRequestFromBackgroundChecksAppStateOnMain() {
        let checked = expectation(description: "App state checked on main")
        let monitor = ReviewSessionMonitor {
            XCTAssertTrue(Thread.isMainThread)
            checked.fulfill()
        }
        let container = DIContainer()
        container.register(SessionMonitoring.self, value: monitor)
        let manager = AppReviewManager(container: container)

        DispatchQueue.global().async { manager.requestReview() }

        wait(for: [checked], timeout: 1)
    }

    func testReleasedManagerDoesNotRunPendingRequest() {
        let drained = expectation(description: "Main queue drained")
        let monitor = ReviewSessionMonitor { XCTFail("Released service must not request a review") }
        let container = DIContainer()
        container.register(SessionMonitoring.self, value: monitor)

        DispatchQueue.main.async {
            var manager: AppReviewManager? = AppReviewManager(container: container)
            manager?.requestReview()
            manager = nil
            DispatchQueue.main.async { drained.fulfill() }
        }

        wait(for: [drained], timeout: 1)
    }

    func testPublicAPIIsObjCVisibleAndDelegatesWithoutIdentifying() {
        let requested = expectation(description: "Review requested")
        let userpilot = MockUserpilot.make(config: .init(token: "review-test").defaultInstance(false))
        let manager = ReviewManagerSpy {
            requested.fulfill()
        }
        userpilot.container.register(AppReviewManaging.self, value: manager)
        XCTAssertTrue(userpilot.responds(to: #selector(Userpilot.requestReview)))

        DispatchQueue.global().async { userpilot.requestReview() }

        wait(for: [requested], timeout: 1)
    }
}

private final class ReviewSessionMonitor: SessionMonitoring {
    private let onRead: () -> Void

    init(onRead: @escaping () -> Void) {
        self.onRead = onRead
    }

    // Keep native presentation disabled while observing when and where the guard is evaluated.
    var isAppActive: Bool {
        onRead()
        return false
    }

    func reset() {}
}

private final class ReviewManagerSpy: AppReviewManaging {
    private let onRequest: () -> Void

    init(onRequest: @escaping () -> Void) {
        self.onRequest = onRequest
    }

    func requestReview() {
        onRequest()
    }
}
