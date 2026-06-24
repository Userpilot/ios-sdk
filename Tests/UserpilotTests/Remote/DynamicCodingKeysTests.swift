//
//  DynamicCodingKeysTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class DynamicCodingKeysTests: XCTestCase {

    private struct EncodedPayload: Encodable {
        let payload: Payload

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            try container.encodeSkippingInvalid(payload)
        }
    }

    func testEncodeSkippingInvalidEncodesSupportedTypesAndOmitsUnsupportedValues() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: Payload = [
            "string": "hello",
            "url": URL(string: "https://example.com/path") as Any,
            "number": NSNumber(value: 42),
            "boolNumber": NSNumber(value: true),
            "bool": false,
            "date": date,
            "array": ["unsupported"]
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(EncodedPayload(payload: payload))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["string"] as? String, "hello")
        XCTAssertEqual(object["url"] as? String, "https://example.com/path")
        XCTAssertEqual(object["number"] as? Int, 42)
        XCTAssertEqual(object["boolNumber"] as? Bool, true)
        XCTAssertEqual(object["bool"] as? Bool, false)
        XCTAssertEqual(object["date"] as? Double, date.timeIntervalSince1970)
        XCTAssertNil(object["array"])
    }

    func testEncodeSkippingInvalidNilPayloadProducesEmptyObject() throws {
        let data = try JSONEncoder().encode(EncodedPayload(payload: nil))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertTrue(object.isEmpty)
    }

    func testEncodeSkippingInvalidOmitsNestedDictionaryAndNullValues() throws {
        let payload: Payload = [
            "valid": "value",
            "nested": ["key": "value"],
            "null": NSNull()
        ]

        let data = try JSONEncoder().encode(EncodedPayload(payload: payload))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["valid"] as? String, "value")
        XCTAssertNil(object["nested"])
        XCTAssertNil(object["null"])
    }

    func testDynamicCodingKeysRejectIntegerInitializer() {
        XCTAssertNil(DynamicCodingKeys(intValue: 1))
        XCTAssertEqual(DynamicCodingKeys(key: "custom").stringValue, "custom")
    }

    func testCodingKeyPrettyFormatsStringAndIntegerPaths() {
        let root = DynamicCodingKeys(key: "root")
        let child = DynamicCodingKeys(key: "child")

        XCTAssertEqual(root.pretty, "root")
        XCTAssertEqual([root, child].pretty, "root.child")
        let mixedPath: [CodingKey] = [IntegerCodingKey(value: 3), child]
        XCTAssertEqual(mixedPath.pretty, "3.child")
    }
}

private struct IntegerCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(value: Int) {
        stringValue = "\(value)"
        intValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.init(value: intValue)
    }
}
