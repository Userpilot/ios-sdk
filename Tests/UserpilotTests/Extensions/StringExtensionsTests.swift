//
//  StringExtensionsTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class StringExtensionsTests: XCTestCase {

    func testStringHelpers() {
        let optionalEmpty: String? = ""
        let optionalValue: String? = "value"

        XCTAssertFalse(optionalEmpty.isNotEmpty)
        XCTAssertTrue(optionalValue.isNotEmpty)
        XCTAssertTrue("value".isNotEmpty)
        XCTAssertEqual("  value \n".trim(), "value")
        XCTAssertEqual("https://example.com/path?x=1".baseURL(), "https://example.com")
        XCTAssertEqual("http://localhost:8080/api/endpoint".baseURL(), "http://localhost")
        XCTAssertNil("not a url".baseURL())
        XCTAssertNil("".baseURL())
        XCTAssertTrue("ar".isRTL)
        XCTAssertTrue("fa".isRTL)
        XCTAssertTrue("he".isRTL)
        XCTAssertTrue("iw".isRTL)
        XCTAssertFalse("en".isRTL)
    }

    func testValidationAndParsingHelpers() {
        XCTAssertEqual("16px".toFontSize, 16)
        XCTAssertEqual("24".toFontSize, 24)
        XCTAssertEqual("18".toSize, 18)
        XCTAssertEqual("bad-value".toFontSize, CGFloat(ThemeHandler.DefaultValues.normalTextSize))
        XCTAssertEqual("".toFontSize, CGFloat(ThemeHandler.DefaultValues.normalTextSize))
        XCTAssertNil("auto".toSize)
        XCTAssertNil("".toSize)
        XCTAssertEqual("https://example.com/image.png".getImageNameWithoutExtension(), "image")
        XCTAssertEqual(
            "https://example.com/assets/image.name.png?size=large".getImageNameWithoutExtension(),
            "image.name"
        )
        XCTAssertEqual("not a url".getImageNameWithoutExtension(), "not a url")
        XCTAssertTrue("test@example.com".isValidEmail())
        XCTAssertFalse("test@example".isValidEmail())
        XCTAssertTrue("test+tag@example.co".isValidEmail())
        XCTAssertTrue("1234567890".isValidPhone())
        XCTAssertFalse("123".isValidPhone())
        XCTAssertTrue("12.5".isNumeric())
        XCTAssertTrue("-12".isNumeric())
        XCTAssertFalse("abc".isNumeric())
    }

    func testJSONStringDecodesObject() throws {
        struct Item: Decodable, Equatable {
            let id: Int
            let name: String
        }

        let item: Item? = "{ \"id\": 3, \"name\": \"Third\" }".toObject()

        XCTAssertEqual(item, Item(id: 3, name: "Third"))
    }

    func testInvalidJSONDecodeReturnsNil() {
        let object: [String: String]? = "not-json".toObject()

        XCTAssertNil(object)
    }

    func testToObject_decodesValidJSON_withoutLogging() {
        let logger = MockLogger()

        let theme = "{\"id\":2,\"theme_data\":null}".toMobileTheme(logger: logger)

        XCTAssertEqual(theme?.id, 2)
        XCTAssertTrue(logger.loggedErrors.isEmpty)
    }

    func testToObject_logsFailure_andReturnsNil() {
        let logger = MockLogger()

        let theme = "{\"id\":\"not-a-number\"}".toMobileTheme(logger: logger)

        XCTAssertNil(theme)
        XCTAssertEqual(logger.loggedErrors.count, 1)
        XCTAssertTrue(logger.loggedErrors.first?.contains("Failed to decode") == true)
    }

    func testToObject_returnsNil_withoutLogging_forEmptyString() {
        let logger = MockLogger()

        XCTAssertNil("".toMobileTheme(logger: logger))
        XCTAssertTrue(logger.loggedErrors.isEmpty)
    }

    func testUnknownEnumValue_dropsContent_andLogsIt() throws {
        let logger = MockLogger()
        var payload = MockContentFactory.makeFlowContentPayload()
        XCTAssertNotNil(payload.toJSONString()?.toFlowContent(logger: logger)?.flowContent)

        var flow = try XCTUnwrap(payload["mobile_contents"] as? [String: Any])
        flow["type"] = "video"
        payload["mobile_contents"] = flow

        XCTAssertNil(try XCTUnwrap(payload.toJSONString()).toFlowContent(logger: logger))
        XCTAssertEqual(logger.loggedErrors.count, 1)
    }

    func testExperienceCandidates_ignoreAbsentContentTypesWithoutLogging() throws {
        let payloads = [
            MockContentFactory.makeFlowContentPayload(),
            MockContentFactory.makeSurveyContentPayload(),
            MockContentFactory.makeNPSContentPayload()
        ]
        for payload in payloads {
            let logger = MockLogger()
            let contents = try XCTUnwrap(payload.toJSONString()).experienceCandidates(logger: logger)
            XCTAssertEqual(contents.count, 1)
            XCTAssertTrue(logger.loggedErrors.isEmpty)
        }
        let logger = MockLogger()
        XCTAssertTrue("{}".experienceCandidates(logger: logger).isEmpty)
        XCTAssertTrue("{\"mobile_contents\":null,\"surveys\":null,\"nps\":null}"
            .experienceCandidates(logger: logger).isEmpty)
        XCTAssertTrue(logger.loggedErrors.isEmpty)
    }

    func testExperienceCandidates_preservePriorityAndContinueAfterMalformedContent() throws {
        var payload = MockContentFactory.makeFlowContentPayload()
        payload.merge(MockContentFactory.makeSurveyContentPayload()) { _, new in new }
        payload.merge(MockContentFactory.makeNPSContentPayload()) { _, new in new }
        let logger = MockLogger()
        let contents = try XCTUnwrap(payload.toJSONString()).experienceCandidates(logger: logger)
        XCTAssertEqual(contents.count, 3)
        XCTAssertNotNil(contents.first?.asFlowContent())
        XCTAssertNotNil(contents.dropFirst().first?.asSurveyContent())
        XCTAssertNotNil(contents.last?.asNPSContent())
        XCTAssertTrue(logger.loggedErrors.isEmpty)

        payload["mobile_contents"] = ["id": "invalid"]
        let remaining = try XCTUnwrap(payload.toJSONString()).experienceCandidates(logger: logger)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertNotNil(remaining.first?.asSurveyContent())
        XCTAssertEqual(logger.loggedErrors.count, 1)
    }
}
