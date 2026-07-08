//
//  DelayUtilsTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class DelayUtilsTests: XCTestCase {

    // MARK: - Properties

    var delayUtils: DelayUtils!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        delayUtils = DelayUtils()
    }

    override func tearDown() {
        delayUtils = nil
        super.tearDown()
    }

    // MARK: - Tests

    /// Verifies that a delayed action is executed after the specified delay.
    func testDelayActionExecutesAfterDelay() {
        let expectation = self.expectation(description: "Delayed action executed")

        delayUtils.delayAction(delayTime: 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
    }

    /// Verifies that cancelling a delay prevents the action from executing.
    func testCancelDelayPreventsExecution() {
        let executionExpectation = expectation(description: "Action should not execute")
        executionExpectation.isInverted = true

        let cancelExpectation = expectation(description: "Cancel should complete")

        // Schedule the delayed action
        delayUtils.delayAction(delayTime: 0.2) {
            executionExpectation.fulfill()
        }

        // Wait a brief moment to ensure the work item is scheduled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            // Cancel the delay
            self?.delayUtils.cancelDelay()

            // Wait for cancel to complete (since it's async)
            DispatchQueue(label: Constants.DispatchQueues.delayQueue).asyncAfter(deadline: .now() + 0.01) {
                DispatchQueue.main.async {
                    cancelExpectation.fulfill()
                }
            }
        }

        // Wait for cancel to complete first, then wait to ensure action doesn't execute
        wait(for: [cancelExpectation], timeout: 1.0)
        wait(for: [executionExpectation], timeout: 0.3)
    }

    /// Verifies that `hasPendingAction()` returns true when a task is scheduled.
    func testHasPendingActionReturnsTrueWhenTaskIsScheduled() {
        let expectation = self.expectation(description: "Delay scheduled")

        delayUtils.delayAction(delayTime: 0.2) {
            // no-op
        }

        // Wait a tiny bit to ensure currentWorkItem is set
        DispatchQueue.main.async {
            XCTAssertTrue(self.delayUtils.hasPendingAction())
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.1)
    }

    /// Verifies that `hasPendingAction()` returns false when no task is scheduled.
    func testHasPendingActionReturnsFalseWhenNoTaskIsScheduled() {
        delayUtils.cancelDelay()
        XCTAssertFalse(delayUtils.hasPendingAction())
    }

    /// Verifies that scheduling a new delayed action cancels the previous one.
    func testSchedulingNewDelayCancelsPrevious() {
        var firstExecuted = false
        var secondExecuted = false

        let firstExpectation = expectation(description: "First should NOT execute")
        firstExpectation.isInverted = true

        let secondExpectation = expectation(description: "Second should execute")

        // Schedule first delayed action
        delayUtils.delayAction(delayTime: 0.2) {
            firstExecuted = true
            firstExpectation.fulfill()
        }

        // Schedule second delayed action before the first one fires
        delayUtils.delayAction(delayTime: 0.1) {
            secondExecuted = true
            secondExpectation.fulfill()
        }

        wait(for: [firstExpectation, secondExpectation], timeout: 0.5)

        XCTAssertFalse(firstExecuted)
        XCTAssertTrue(secondExecuted)
    }
}
