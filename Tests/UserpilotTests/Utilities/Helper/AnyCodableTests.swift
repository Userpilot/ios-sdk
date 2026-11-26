//
//  AnyCodableTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins heterogeneous offline JSON values without broadening the metadata type policy.
//

import Foundation
import XCTest
@testable import Userpilot

final class AnyCodableTests: XCTestCase {
    func testDecoding_preservesNestedValuesAndIntegerPrecision() throws {
        let json = """
        {"id":9007199254740993,"maximum":9223372036854775807,"active":true,"empty":null,
         "items":[{"ratio":2.5},false,null]}
        """
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: Data(json.utf8))

        XCTAssertEqual(decoded["id"]?.value as? Int, 9_007_199_254_740_993)
        XCTAssertEqual(decoded["maximum"]?.value as? Int, Int.max)
        XCTAssertEqual(decoded["active"]?.value as? Bool, true)
        XCTAssertTrue(decoded["empty"]?.value is NSNull)
        let items = try XCTUnwrap(decoded["items"]?.value as? [Any])
        XCTAssertEqual((items[0] as? [String: Any])?["ratio"] as? Double, 2.5)
        XCTAssertEqual(items[1] as? Bool, false)
        XCTAssertTrue(items[2] is NSNull)
    }

    func testEncoding_preservesNullSlotsAndUnsupportedValuePolicy() throws {
        let value: [String: Any] = [
            "name": "Ada", "active": true, "id": 9_007_199_254_740_993,
            "items": [NSNull(), Date(timeIntervalSince1970: 0)],
            "unsupported": Date(timeIntervalSince1970: 0)
        ]
        let encoded = try JSONEncoder().encode(AnyCodable(value))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(object["name"] as? String, "Ada")
        XCTAssertEqual(object["active"] as? Bool, true)
        XCTAssertEqual(object["id"] as? Int, 9_007_199_254_740_993)
        XCTAssertTrue(object["unsupported"] is NSNull)
        let items = try XCTUnwrap(object["items"] as? [Any])
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { $0 is NSNull })
    }

    func testEncoding_retainsFoundationNumberCastOrder() throws {
        let encoded = try JSONEncoder().encode(AnyCodable(NSNumber(value: true)))
        // NSNumber bridges to Int before Bool in the existing offline encoder.
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "1")
    }

    func testDecoding_preservesNullRoot() throws {
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: Data("null".utf8))
        XCTAssertTrue(decoded.value is NSNull)
    }
}
