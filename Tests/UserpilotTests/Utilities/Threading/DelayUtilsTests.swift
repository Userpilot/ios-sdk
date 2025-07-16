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

    var delayUtils: DelayUtils!

    override func setUp() {
        super.setUp()
        delayUtils = DelayUtils()
    }

    override func tearDown() {
        delayUtils = nil
        super.tearDown()
    }

    func testDelayActionExecutesAfterDelay() {
        // Arrange
        let expectation = self.expectation(description: "Delayed action executed")

        // Act
        delayUtils.delayAction(delayTime: 0.1) {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 0.5)
    }

    func testCancelDelayPreventsExecution() {
        // Arrange
        let expectation = self.expectation(description: "Action should not execute")
        expectation.isInverted = true

        // Act
        delayUtils.delayAction(delayTime: 0.2) {
            expectation.fulfill()
        }

        delayUtils.cancelDelay()

        // Assert
        wait(for: [expectation], timeout: 0.4)
    }

    func testHasPendingContentReturnsTrueWhenTaskIsScheduled() {
        // Act
        delayUtils.delayAction(delayTime: 0.2) {
            // no-op
        }

        // Assert
        XCTAssertTrue(delayUtils.hasPendingContent())
    }

    func testHasPendingContentReturnsFalseWhenNoTaskIsScheduled() {
        // Act
        delayUtils.cancelDelay()
        XCTAssertFalse(delayUtils.hasPendingContent())
    }

    func testSchedulingNewDelayCancelsPrevious() {
        // Arrange
        var firstExecuted = false
        var secondExecuted = false

        let firstExpectation = expectation(description: "First should NOT execute")
        firstExpectation.isInverted = true

        let secondExpectation = expectation(description: "Second should execute")

        // Act
        delayUtils.delayAction(delayTime: 0.2) {
            firstExecuted = true
            firstExpectation.fulfill()
        }

        // Schedule second delay before first one fires
        delayUtils.delayAction(delayTime: 0.1) {
            secondExecuted = true
            secondExpectation.fulfill()
        }

        // Assert
        wait(for: [firstExpectation, secondExpectation], timeout: 0.5)
        XCTAssertFalse(firstExecuted)
        XCTAssertTrue(secondExecuted)
    }
}
