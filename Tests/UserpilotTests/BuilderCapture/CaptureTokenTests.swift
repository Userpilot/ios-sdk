//
//  CaptureTokenTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the Builder token is only ever exposed through its bearer header.
//

import XCTest
@testable import Userpilot

final class CaptureTokenTests: XCTestCase {

    func testMissingOrBlankValueHasNoToken() {
        XCTAssertNil(CaptureToken(nil))
        XCTAssertNil(CaptureToken(""))
        XCTAssertNil(CaptureToken("  \n"))
    }

    func testBearerHeaderCarriesTheRawValue() throws {
        let token = try XCTUnwrap(CaptureToken("secret-builder-token"))
        XCTAssertEqual(token.bearerHeader(), "Bearer secret-builder-token")
    }

    func testEveryDescriptionIsRedacted() throws {
        let token = try XCTUnwrap(CaptureToken("secret-builder-token"))
        var dumped = ""
        dump(token, to: &dumped)

        for text in ["\(token)", String(describing: token), String(reflecting: token), dumped] {
            XCTAssertFalse(text.contains("secret-builder-token"), text)
        }
        XCTAssertEqual(token.description, "CaptureToken(<redacted>)")
    }
}
