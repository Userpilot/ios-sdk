//
//  OneSecondFlagTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class OneSecondFlagTests: XCTestCase {
    var flag: OneSecondFlag!

    override func setUp() {
        super.setUp()
        flag = OneSecondFlag()
    }

    override func tearDown() {
        flag = nil
        super.tearDown()
    }

    func testActivateSetsIsActiveTrueImmediately() {
        // Act
        flag.activate()
        
        // Assert
        XCTAssertTrue(flag.isActive)
    }

    func testIsActiveBecomesFalseAfterOneSecond() {
        // Arrange
        let expectation = XCTestExpectation(description: "isActive becomes false after 1 second")

        // Act
        flag.activate()
        
        // Assert
        XCTAssertTrue(flag.isActive)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            XCTAssertFalse(self.flag.isActive)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testActivateMultipleTimesResetsTimer() {
        // Arrange
        let expectation = XCTestExpectation(description: "isActive stays true and then becomes false 1 second after last activate")

        // Act
        flag.activate()
        
        // Assert
        XCTAssertTrue(flag.isActive)

        // Call activate again after 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.flag.activate()
            XCTAssertTrue(self.flag.isActive)
        }

        // Check after 1.2 seconds from now (so 1.7s from first activate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            XCTAssertFalse(self.flag.isActive)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
