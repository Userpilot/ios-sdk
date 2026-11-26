//
//  DebugUserSnapshotFactoryTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugUserSnapshotFactoryTests: XCTestCase {

    func testSnapshot_exposesStoredIdentityWithoutReconstructingAProfile() {
        let storage = MockStorage()
        storage.userId = "user-9"
        storage.anonymousUserId = "anon-1"
        storage.sessionDate = nil
        storage.configurationDate = nil
        storage.temporaryUser = nil

        let snapshot = DebugUserSnapshotFactory(storage: storage).create()

        XCTAssertEqual(snapshot.sections.map(\.title), ["Identity"])
        XCTAssertEqual(snapshot.sections[0].rows.first { $0.key == "user_id" }?.value, "user-9")
        XCTAssertEqual(snapshot.sections[0].rows.first { $0.key == "anonymous_user_id" }?.value, "anon-1")
        XCTAssertEqual(snapshot.sections[0].rows.first { $0.key == "session_date" }?.value, "—")
    }
}

// swiftlint:enable all
