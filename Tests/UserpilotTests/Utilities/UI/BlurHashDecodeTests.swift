//
//  BlurHashDecodeTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class BlurHashDecodeTests: XCTestCase {

    func testBlurHashReturnsNilForShortOrLengthMismatchedHashes() {
        XCTAssertNil(UIImage(blurHash: "abc", size: CGSize(width: 4, height: 4)))
        XCTAssertNil(UIImage(
            blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj-extra",
            size: CGSize(width: 4, height: 4)
        ))
    }

    func testBlurHashDecodesValidHashAtRequestedSize() throws {
        let image = try XCTUnwrap(UIImage(
            blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
            size: CGSize(width: 4, height: 3)
        ))

        XCTAssertEqual(image.size.width, 4)
        XCTAssertEqual(image.size.height, 3)
    }

    func testDecode83ConvertsBlurHashAlphabetCharacters() {
        XCTAssertEqual("0".decode83(), 0)
        XCTAssertEqual("1".decode83(), 1)
        XCTAssertEqual("A".decode83(), 10)
        XCTAssertEqual("~".decode83(), 82)
        XCTAssertEqual("10".decode83(), 83)
    }
}
