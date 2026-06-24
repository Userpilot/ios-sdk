//
//  FoundationExtensionsTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class FoundationExtensionsTests: XCTestCase {

    func testDateIsMoreThanOneSecondUsesAbsoluteDifferenceAndStrictBoundary() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertFalse(now.isMoreThanOneSecond(from: now.addingTimeInterval(1.0)))
        XCTAssertFalse(now.isMoreThanOneSecond(from: now.addingTimeInterval(-1.0)))
        XCTAssertTrue(now.isMoreThanOneSecond(from: now.addingTimeInterval(1.01)))
        XCTAssertTrue(now.isMoreThanOneSecond(from: now.addingTimeInterval(-1.01)))
    }

    func testURLHttpSchemeDetection() throws {
        XCTAssertTrue(try XCTUnwrap(URL(string: "http://example.com")).isHttpOrHttps)
        XCTAssertTrue(try XCTUnwrap(URL(string: "https://example.com")).isHttpOrHttps)
        XCTAssertFalse(try XCTUnwrap(URL(string: "ftp://example.com")).isHttpOrHttps)
        XCTAssertFalse(try XCTUnwrap(URL(string: "mailto:test@example.com")).isHttpOrHttps)
    }

    func testHTTPURLResponseSuccessStatusCodeRange() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertFalse(try response(url: url, statusCode: 199).isSuccessStatusCode)
        XCTAssertTrue(try response(url: url, statusCode: 200).isSuccessStatusCode)
        XCTAssertTrue(try response(url: url, statusCode: 299).isSuccessStatusCode)
        XCTAssertFalse(try response(url: url, statusCode: 300).isSuccessStatusCode)
    }

    func testNumericAndCollectionHelpers() {
        var value = 10

        value.increment()
        XCTAssertEqual(value, 11)

        value.increment(by: 4)
        XCTAssertEqual(value, 15)

        value.increment(by: -5)
        XCTAssertEqual(value, 10)

        XCTAssertEqual(CGFloat(12).negative, -12)
        XCTAssertEqual(5.clamped(to: 1...10), 5)
        XCTAssertEqual((-1).clamped(to: 1...10), 1)
        XCTAssertEqual(11.clamped(to: 1...10), 10)
        XCTAssertEqual(["a", "b"][safe: 1], "b")
        XCTAssertNil(["a", "b"][safe: 2])
    }

    func testCollectionSafeSubscriptSupportsNonIntegerIndexes() {
        let value = "abcd"
        let validIndex = value.index(value.startIndex, offsetBy: 2)
        let invalidIndex = value.endIndex

        XCTAssertEqual(value[safe: validIndex], "c")
        XCTAssertNil(value[safe: invalidIndex])
    }

    func testPerformOnDispatchesClosure() {
        let expectation = expectation(description: "closure executed")

        performOn(.highPriority) {
            XCTAssertFalse(Thread.isMainThread)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    private func response(url: URL, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
    }
}
