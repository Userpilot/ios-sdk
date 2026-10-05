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

    func testPendingIdentifyRoundTripDoesNotMergePreviousProfile() throws {
        let previous = User(userId: "user-1", properties: ["role": "admin"], company: ["id": "old"])
        let incoming = User(userId: "user-1", properties: ["name": "New"], company: ["plan": "pro"])

        let decoded = User.fromJson(try XCTUnwrap(incoming.toJson()))

        XCTAssertEqual(decoded.userId, previous.userId)
        XCTAssertNil(decoded.properties["role"])
        XCTAssertEqual(decoded.properties["name"] as? String, "New")
        XCTAssertNil(decoded.company["id"])
        XCTAssertEqual(decoded.company["plan"] as? String, "pro")
    }

    func testFromJsonRejectsIncompletePendingIdentify() {
        let user = User.fromJson("{\"userId\":\"new-user\"}")
        XCTAssertEqual(user.userId, "")
        XCTAssertTrue(user.properties.isEmpty)
        XCTAssertTrue(user.company.isEmpty)
    }
}
