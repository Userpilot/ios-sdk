//
//  DebouncerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class DebouncerTests: XCTestCase {

    func testDebounceExecutesActionAfterDelay() {
        // Arrange
        let expectation = self.expectation(description: "Debounced action executed")

        // Act
        let debouncer = Debouncer(delay: 0.1, queue: .main)
        debouncer.debounce {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 0.5)
    }

    func testDebounceReplacesPreviousAction() {
        // Arrange
        let expectation = self.expectation(description: "Only latest action is executed")

        var executedValue = 0

        // Act
        let debouncer = Debouncer(delay: 0.1, queue: .main)

        debouncer.debounce {
            executedValue = 1
        }

        debouncer.debounce {
            executedValue = 2
        }

        debouncer.debounce {
            executedValue = 3
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)

        // Assert
        XCTAssertEqual(executedValue, 3)
    }

    func testDebounceCancelPreventsExecution() {
        // Arrange
        let expectation = self.expectation(description: "Action should not execute")
        expectation.isInverted = true

        // Act
        let debouncer = Debouncer(delay: 0.1, queue: .main)

        debouncer.debounce {
            expectation.fulfill()
        }

        debouncer.cancel()

        // Assert
        wait(for: [expectation], timeout: 0.3)
    }
}
