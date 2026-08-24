//
//  DebugUserSnapshotFactoryTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugUserSnapshotFactoryTests: XCTestCase {

    func testSnapshot_exposesCachedIdentityPropertiesAndCompany() {
        let cached = User(
            userId: "user-9",
            properties: ["email": "dev@userpilot.com", "plan": "pro"],
            company: ["name": "Userpilot"]
        )
        let storage = MockStorage()
        storage.userId = "user-9"
        storage.anonymousUserId = "anon-1"
        storage.user = cached.toJson() ?? ""
        storage.sessionDate = nil
        storage.configurationDate = nil
        storage.temporaryUser = nil

        let snapshot = DebugUserSnapshotFactory(storage: storage).create()
        let keys = snapshot.sections.flatMap { $0.rows.map(\.key) }

        XCTAssertEqual(snapshot.sections.map(\.title), ["Identity", "Properties", "Company"])
        for key in ["user_id", "anonymous_user_id", "email", "plan", "name"] {
            XCTAssertTrue(keys.contains(key), "missing key \(key)")
        }
        XCTAssertEqual(snapshot.sections[0].rows.first { $0.key == "user_id" }?.value, "user-9")
        XCTAssertEqual(snapshot.sections[1].rows.first { $0.key == "email" }?.value, "dev@userpilot.com")
        XCTAssertEqual(snapshot.sections[2].rows.first { $0.key == "name" }?.value, "Userpilot")
        XCTAssertEqual(snapshot.sections[0].rows.first { $0.key == "session_date" }?.value, "—")
    }
}

// swiftlint:enable all
