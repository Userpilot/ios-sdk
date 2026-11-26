//
//  CaptureLinkTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers QR capture link validation: required values, decoding, ignored extra query items and redaction.
//

import XCTest
@testable import Userpilot

final class CaptureLinkTests: XCTestCase {

    func testAllValidValuesBuildTheLink() throws {
        let link = try XCTUnwrap(CaptureLink.from(captureID: "cap-1", platform: "ios", token: "secret-token"))

        XCTAssertEqual(link.captureID, "cap-1")
        XCTAssertEqual(link.token.bearerHeader(), "Bearer secret-token")
        XCTAssertNil(CaptureLink.invalidField(captureID: "cap-1", platform: "ios", token: "secret-token"))
    }

    func testEachMissingOrBlankValueIsNamed() {
        for missing in [nil, "", "  "] {
            XCTAssertNil(CaptureLink.from(captureID: missing, platform: "ios", token: "secret-token"))
            XCTAssertNil(CaptureLink.from(captureID: "cap-1", platform: missing, token: "secret-token"))
            XCTAssertNil(CaptureLink.from(captureID: "cap-1", platform: "ios", token: missing))
            XCTAssertEqual(CaptureLink.invalidField(captureID: missing, platform: "ios", token: "secret-token"),
                           .captureID)
            XCTAssertEqual(CaptureLink.invalidField(captureID: "cap-1", platform: missing, token: "secret-token"),
                           .platform)
            XCTAssertEqual(CaptureLink.invalidField(captureID: "cap-1", platform: "ios", token: missing), .token)
        }
        XCTAssertEqual(CaptureLink.invalidField(captureID: "cap-1", platform: "web", token: "secret-token"),
                       .platform)
        XCTAssertEqual(CaptureLink.invalidField(captureID: nil, platform: nil, token: nil), .captureID,
                       "Checked in link order")
        XCTAssertEqual(CaptureLink.Field.allCases.map(\.rawValue), ["capture_id", "platform", "token"])
    }

    func testQueryValuesAreDecodedAndARawPlusSignIsKept() throws {
        // A capture token can contain `+`; reading it as a space would break the credential.
        let link = try XCTUnwrap(parse("capture_id=cap%201&platform=ios&token=tok+en%2B1%3D"))

        XCTAssertEqual(link.captureID, "cap 1")
        XCTAssertEqual(link.token.bearerHeader(), "Bearer tok+en+1=")
    }

    func testAnExtraUploadURLItemIsIgnored() throws {
        let link = try XCTUnwrap(parse(
            "capture_id=cap-1&platform=ios&token=secret-token&upload_url=https%3A%2F%2Fevil.com%2Fupload"))

        XCTAssertEqual(link, CaptureLink.from(captureID: "cap-1", platform: "ios", token: "secret-token"))
    }

    func testDescriptionsNeverShowTheToken() throws {
        let link = try XCTUnwrap(CaptureLink.from(captureID: "cap-1", platform: "ios", token: "secret-token"))
        var dumped = ""
        dump(link, to: &dumped)

        for text in ["\(link)", String(reflecting: link), dumped] {
            XCTAssertFalse(text.contains("secret-token"), text)
        }
    }

    // MARK: - Helpers

    /// The link the deep-link handler reads from a capture URL with `query`; nil when it is invalid.
    private func parse(_ query: String) -> CaptureLink? {
        let url = URL(string: "userpilot-nx-12345://sdk/capture?\(query)")
        guard case let .capture(link)? = url.flatMap({ DeepLinkHandler.Action(url: $0, token: "NX-12345") }) else {
            XCTFail("Expected a capture action for \(query)")
            return nil
        }
        return link
    }
}
