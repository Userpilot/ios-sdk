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
        let expectation = self.expectation(description: "Action should not execute")
        expectation.isInverted = true

        delayUtils.delayAction(delayTime: 0.2) {
            expectation.fulfill()
        }

        delayUtils.cancelDelay()

        wait(for: [expectation], timeout: 0.4)
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
