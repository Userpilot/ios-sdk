//
//  UserTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class UserTests: XCTestCase {

    func testJsonRoundTripPreservesUserPropertiesAndCompany() throws {
        let user = User(
            userId: "user-1",
            properties: ["email": "test@example.com", "age": 32],
            company: ["id": "company-1", "plan": "pro"]
        )

        let json = try XCTUnwrap(user.toJson())
        let decoded = User.fromJson(json)

        XCTAssertEqual(decoded.userId, "user-1")
        XCTAssertEqual(decoded.properties["email"] as? String, "test@example.com")
        XCTAssertEqual(decoded.properties["age"] as? Int, 32)
        XCTAssertEqual(decoded.company["id"] as? String, "company-1")
        XCTAssertEqual(decoded.company["plan"] as? String, "pro")
    }

    func testFromJsonReturnsEmptyUserForInvalidJson() {
        let decoded = User.fromJson("{invalid")

        XCTAssertEqual(decoded.userId, "")
        XCTAssertTrue(decoded.properties.isEmpty)
        XCTAssertTrue(decoded.company.isEmpty)
    }

    func testUpdateUserMergesPropertiesForSameUser() {
        var user = User(
            userId: "user-1",
            properties: ["name": "Old", "role": "admin"],
            company: ["id": "company-1"]
        )
        let event = Event(
            type: .identify("user-1"),
            properties: ["name": "New", "email": "new@example.com"],
            company: ["plan": "enterprise"]
        )

        let updated = user.updateUser(event: event)

        XCTAssertEqual(updated.userId, "user-1")
        XCTAssertEqual(updated.properties["name"] as? String, "New")
        XCTAssertEqual(updated.properties["role"] as? String, "admin")
        XCTAssertEqual(updated.properties["email"] as? String, "new@example.com")
        XCTAssertEqual(updated.company["id"] as? String, "company-1")
        XCTAssertEqual(updated.company["plan"] as? String, "enterprise")
    }

    func testUpdateUserResetsWhenEventUserChanges() {
        var user = User(
            userId: "old-user",
            properties: ["old": "value"],
            company: ["oldCompany": "value"]
        )
        let event = Event(
            type: .identify("new-user"),
            properties: ["new": "value"],
            company: ["company": "new"]
        )

        let updated = user.updateUser(event: event)

        XCTAssertEqual(updated.userId, "new-user")
        XCTAssertNil(updated.properties["old"])
        XCTAssertEqual(updated.properties["new"] as? String, "value")
        XCTAssertNil(updated.company["oldCompany"])
        XCTAssertEqual(updated.company["company"] as? String, "new")
    }

    func testIsSameIdentifyEventSupportsPartialUpdates() {
        let user = User(
            userId: "user-1",
            properties: [
                "name": "Jane",
                "profile": ["role": "admin", "tier": 2],
                "scores": [1, "two", true]
            ],
            company: ["id": "company-1", "size": 10]
        )
        let event = Event(
            type: .identify("user-1"),
            properties: [
                "profile": ["role": "admin", "tier": 2],
                "scores": [1, "two", true]
            ],
            company: ["id": "company-1"]
        )

        XCTAssertTrue(user.isSameIdentifyEvent(event: event))
        XCTAssertTrue(user.isSameIdentifyEvent(event: event, strategy: .partialUpdate))
    }

    func testIsSameIdentifyEventExactMatchRequiresSameKeys() {
        let user = User(userId: "user-1", properties: ["name": "Jane", "age": 30], company: [:])
        let partialEvent = Event(type: .identify("user-1"), properties: ["name": "Jane"], company: [:])
        let exactEvent = Event(type: .identify("user-1"), properties: ["name": "Jane", "age": 30], company: [:])

        XCTAssertFalse(user.isSameIdentifyEvent(event: partialEvent, strategy: .exactMatch))
        XCTAssertTrue(user.isSameIdentifyEvent(event: exactEvent, strategy: .exactMatch))
    }

    func testIsSameIdentifyEventIgnoreEmptyValues() {
        let user = User(
            userId: "user-1",
            properties: ["name": "Jane", "empty": "", "emptyArray": [Any]()],
            company: ["id": "company-1", "emptyCompany": [String: Any]()]
        )
        let event = Event(
            type: .identify("user-1"),
            properties: ["name": "Jane", "empty": ""],
            company: ["id": "company-1", "emptyCompany": [String: Any]()]
        )

        XCTAssertTrue(user.isSameIdentifyEvent(event: event, strategy: .ignoreEmpty))
    }

    func testDictionaryComparisonSupportsNumbersToleranceAndNilValues() {
        let dict: [String: Any] = [
            "intAsDouble": 1,
            "double": 1.00001,
            "float": Float(2.00001),
            "null": NSNull()
        ]

        XCTAssertTrue(dict.containsAll(from: [
            "intAsDouble": 1.0,
            "double": 1.00002,
            "float": Float(2.00002),
            "null": NSNull()
        ]))
        XCTAssertFalse(dict.containsAll(from: ["double": 1.2]))
    }
}
