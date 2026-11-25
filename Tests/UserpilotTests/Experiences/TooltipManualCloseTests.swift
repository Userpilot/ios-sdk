//
//  TooltipManualCloseTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The host app's `endExperience()` ends a revealed tooltip step like its close button; a step
//  that was never revealed, and any SDK-driven close, end silently.
//

import XCTest
@testable import Userpilot

extension TooltipPagingTests {

    func testAManualClose_endsTheRevealedStepLikeTheCloseButton_once() {
        let sut = makeRevealedController(stepCount: 2)
        let closed = expectation(description: "manual close removed the tooltip")

        sut.triggerCloseExperience(manualClose: true) { closed.fulfill() }
        sut.wrapperView.cardView.onClose?()
        wait(for: [closed], timeout: 1)

        XCTAssertEqual(harness.flowEvents.map(\.eventName), ["seen_mobile_content_step", "dismissed_mobile_content"])
        XCTAssertEqual(harness.flowEvents.last?.eventPayload["step_id"] as? Int, 0)
        XCTAssertTrue(sut.viewModel.isFlowRunEnded)
    }

    func testAManualClose_beforeTheFirstStepIsRevealed_closesSilently() {
        let sut = makeController(stepCount: 1)
        present(sut)

        sut.triggerCloseExperience(manualClose: true, completion: nil)

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertTrue(harness.flowEvents.isEmpty)
        XCTAssertFalse(sut.viewModel.isFlowRunEnded)
    }

    func testAManualClose_ofAParkedStep_closesSilently() {
        let sut = makeController(stepCount: 2, resolvable: ["tooltip-target-0"])
        targeting.isAtEnd = false
        present(sut)
        sut.targetCoordinator.start(retryIntervals: sut.retryIntervals)
        sut.handleAction(nil)   // step 1's target is not on screen: it parks
        let parked = expectation(for: NSPredicate { _, _ in sut.isParked }, evaluatedWith: nil)
        wait(for: [parked], timeout: 2)
        let eventsBeforeClose = harness.flowEvents.map(\.eventName)

        sut.triggerCloseExperience(manualClose: true, completion: nil)

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertEqual(eventsBeforeClose, ["seen_mobile_content_step", "completed_mobile_content_step"])
        XCTAssertEqual(harness.flowEvents.map(\.eventName), eventsBeforeClose)
        XCTAssertFalse(sut.viewModel.isFlowRunEnded)
    }

    func testAnSDKClose_ofARevealedStep_sendsNothing() {
        let sut = makeRevealedController(stepCount: 2)

        sut.triggerCloseExperience(manualClose: false, completion: nil)

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertEqual(harness.flowEvents.map(\.eventName), ["seen_mobile_content_step"])
        XCTAssertFalse(sut.viewModel.isFlowRunEnded)
    }
}
