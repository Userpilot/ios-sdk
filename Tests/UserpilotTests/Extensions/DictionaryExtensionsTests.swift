//
//  DictionaryExtensionsTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class DictionaryExtensionsTests: XCTestCase {

    func testMergingPrefersNewValues() {
        let original = ["a": 1, "b": 2]
        let merged = original.merging(["b": 3, "c": 4])

        XCTAssertEqual(merged, ["a": 1, "b": 3, "c": 4])
    }

    func testToJSONStringSerializesDictionary() throws {
        let json = try XCTUnwrap(["name": "Jane", "age": 30].toJSONString())
        let data = try XCTUnwrap(json.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["name"] as? String, "Jane")
        XCTAssertEqual(object["age"] as? Int, 30)
    }
}
