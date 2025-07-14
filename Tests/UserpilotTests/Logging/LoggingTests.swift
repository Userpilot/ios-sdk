//
//  LoggingTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class LoggingTests: XCTestCase {

    private var logger: MockLogger!

    override func setUp() {
        super.setUp()
        logger = MockLogger()
    }

    // MARK: – Helpers
    private func assert(
        _ array: [String],
        contains expected: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(array.count, 1, file: file, line: line)
        XCTAssertEqual(array.first, expected, file: file, line: line)
    }

    // MARK: – Individual log‑level tests
    func testDebugCapturesMessage() {
        logger.debug("Debug value: %@", String(123))
        assert(logger.loggedDebugs, contains: "Debug value: 123")
    }

    func testInfoCapturesMessage() {
        logger.info("Info message: %@", "hello")
        assert(logger.loggedInfos, contains: "Info message: hello")
    }

    func testLogCapturesMessage() {
        logger.log("Generic log: %@", "abc")
        assert(logger.loggedLogs, contains: "Generic log: abc")
    }

    func testErrorCapturesMessage() {
        logger.error("Error occurred: %@", "boom")
        assert(logger.loggedErrors, contains: "Error occurred: boom")
    }

    func testFaultCapturesMessage() {
        logger.fault("Fatal fault: %@", "💥")
        assert(logger.loggedFaults, contains: "Fatal fault: 💥")
    }

    // MARK: – Multiple arguments & formatting
    func testMultipleArgumentFormatting() {
        logger.debug("x=%d, y=%@", 10, "twenty")
        XCTAssertEqual(logger.loggedDebugs.first, "x=10, y=twenty")
    }

    // MARK: – Counts by level
    func testCountsAreSeparatedPerLevel() {
        logger.debug("one")
        logger.info("two")
        logger.error("three")

        XCTAssertEqual(logger.loggedDebugs.count, 1)
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertEqual(logger.loggedErrors.count, 1)
        XCTAssertTrue(logger.loggedLogs.isEmpty)
        XCTAssertTrue(logger.loggedFaults.isEmpty)
    }
}
