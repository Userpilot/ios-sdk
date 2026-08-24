//
//  DebugSnapshotTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugSnapshotTests: XCTestCase {

    func testToListItems_flattensSectionsIntoHeadersAndRows() {
        let snapshot = DebugSnapshot(
            sections: [
                DebugSection(title: "SDK", rows: [DebugProperty(key: "token", value: "NX-1")]),
                DebugSection(title: "Push", rows: [DebugProperty(key: "apns_token", value: "abc")])
            ]
        )

        XCTAssertEqual(
            snapshot.toListItems(),
            [
                .header("SDK"),
                .row(key: "token", value: "NX-1"),
                .header("Push"),
                .row(key: "apns_token", value: "abc")
            ]
        )
    }
}

// swiftlint:enable all
