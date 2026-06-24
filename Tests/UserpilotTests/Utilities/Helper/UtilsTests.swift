//
//  UtilsTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class UtilsTests: XCTestCase {

    func testSanitizePayloadKeepsSupportedScalarTypesAndNumbers() {
        let logger = MockLogger()
        let payload: Payload = [
            "string": "value",
            "bool": true,
            "int": 3,
            "int64": Int64(4),
            "double": 1.5,
            "float": Float(2.5),
            "number": NSNumber(value: 9)
        ]

        let sanitized = sanitizePayload(payload, payloadName: "properties", logger: logger)

        XCTAssertEqual(sanitized?["string"] as? String, "value")
        XCTAssertEqual(sanitized?["bool"] as? Bool, true)
        XCTAssertEqual(sanitized?["int"] as? Int, 3)
        XCTAssertEqual(sanitized?["int64"] as? Int64, 4)
        XCTAssertEqual(sanitized?["double"] as? Double, 1.5)
        XCTAssertEqual(sanitized?["float"] as? Float, 2.5)
        XCTAssertEqual(sanitized?["number"] as? NSNumber, NSNumber(value: 9))
        XCTAssertTrue(logger.loggedErrors.isEmpty)
    }

    func testSanitizePayloadDropsUnsupportedValuesAndReturnsNilWhenEmpty() {
        let logger = MockLogger()

        let sanitized = sanitizePayload(
            [
                "array": ["a", "b"],
                "date": Date(timeIntervalSince1970: 0),
                "dict": ["nested": true]
            ],
            payloadName: "company",
            logger: logger
        )

        XCTAssertNil(sanitized)
        XCTAssertEqual(logger.loggedErrors.count, 3)
        XCTAssertTrue(logger.loggedErrors.allSatisfy { $0.contains("Dropped unsupported property in company") })
    }

    func testSanitizePayloadKeepsValidValuesWhenDroppingUnsupportedValues() {
        let logger = MockLogger()

        let sanitized = sanitizePayload(
            [
                "valid": "value",
                "alsoValid": NSNumber(value: true),
                "invalid": URL(string: "https://example.com") as Any
            ],
            payloadName: "properties",
            logger: logger
        )

        XCTAssertEqual(sanitized?["valid"] as? String, "value")
        XCTAssertEqual(sanitized?["alsoValid"] as? Bool, true)
        XCTAssertNil(sanitized?["invalid"])
        XCTAssertEqual(logger.loggedErrors.count, 1)
        XCTAssertTrue(logger.loggedErrors.first?.contains("\"invalid\"") ?? false)
    }

    func testSanitizePayloadEmptyDictionaryReturnsNilWithoutLogging() {
        let logger = MockLogger()

        XCTAssertNil(sanitizePayload([:], payloadName: "properties", logger: logger))
        XCTAssertTrue(logger.loggedErrors.isEmpty)
    }

    func testSanitizePayloadReturnsNilForNilPayload() {
        let logger = MockLogger()

        XCTAssertNil(sanitizePayload(nil, payloadName: "properties", logger: logger))
        XCTAssertTrue(logger.loggedErrors.isEmpty)
    }

    func testTryCatchVoidSuppressesThrownErrorAndContinues() {
        var didContinue = false

        tryCatch {
            throw TestError.expected
        }
        didContinue = true

        XCTAssertTrue(didContinue)
    }

    func testTryCatchValueReturnsResultOrDefault() {
        let success: Int? = tryCatch { 42 }
        let fallback: Int? = tryCatch(
            code: { throw TestError.expected },
            defaultValue: 7
        )
        let nilFallback: Int? = tryCatch {
            throw TestError.expected
        }

        XCTAssertEqual(success, 42)
        XCTAssertEqual(fallback, 7)
        XCTAssertNil(nilFallback)
    }

    func testLoadJSONFileDecodesBundledCountries() throws {
        let countries = try XCTUnwrap(loadJSONFile(named: "countries", as: CountriesEntity.self))

        XCTAssertFalse(countries.isEmpty)
        XCTAssertTrue(countries.contains { $0.name == "United States" && $0.dialCode == "+1" })
        XCTAssertTrue(countries.allSatisfy { !$0.name.isEmpty && !$0.dialCode.isEmpty })
        XCTAssertTrue(countries.contains { !$0.flag.isEmpty })
    }

    func testLoadJSONFileReturnsNilForMissingFileOrMismatchedType() {
        XCTAssertNil(loadJSONFile(named: "missing-file", as: CountriesEntity.self))
        XCTAssertNil(loadJSONFile(named: "countries", as: CountryEntity.self))
    }

    private enum TestError: Error {
        case expected
    }
}
