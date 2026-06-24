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

    func testJSONStringDecodesArrayAndObject() throws {
        struct Item: Decodable, Equatable {
            let id: Int
            let name: String
        }

        let items: [Item]? = """
        [
          { "id": 1, "name": "First" },
          { "id": 2, "name": "Second" }
        ]
        """.toArray()

        let item: Item? = "{ \"id\": 3, \"name\": \"Third\" }".toObject()

        XCTAssertEqual(items, [Item(id: 1, name: "First"), Item(id: 2, name: "Second")])
        XCTAssertEqual(item, Item(id: 3, name: "Third"))
    }

    func testInvalidJSONDecodeReturnsNil() {
        let items: [String]? = "not-json".toArray()
        let object: [String: String]? = "not-json".toObject()

        XCTAssertNil(items)
        XCTAssertNil(object)
    }
}
