//
//  RatingIconTests.swift
//  Userpilot SDK
//
//  Pins the icon a rating cell draws: bundled face names per scale, stars and hearts, none for numbers.
//

import XCTest
@testable import Userpilot

final class RatingIconTests: XCTestCase {
    func testSmileScalesUseTheNativeAssetNamesInAndroidOrder() {
        let suffixes = [
            3: ["three", "five", "nine"],
            5: ["three", "five", "six", "nine", "ten"],
            7: ["one", "three", "five", "six", "seven", "nine", "ten"],
            // Same as Android's ratingIcon: one to ten, in order.
            10: ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        ]
        for (range, names) in suffixes {
            for (index, suffix) in names.enumerated() {
                XCTAssertEqual(
                    LikertViewType.emojis.ratingIcon(index: index, range: range), "userpilot_icon_smile_\(suffix)",
                    "range \(range) index \(index)")
            }
        }
    }

    func testEveryEmojiCellNamesARealAsset() throws {
        for range in [3, 5, 7, 10] {
            for index in 0..<range {
                let name = try XCTUnwrap(LikertViewType.emojis.ratingIcon(index: index, range: range))
                let image = UIImage(named: name, in: Userpilot.resourceBundle, compatibleWith: nil)
                XCTAssertNotNil(image, "\(name) must ship in the bundle")
            }
        }
    }

    func testStarsHeartsAndNumbersKeepTheirImageRules() {
        XCTAssertEqual(LikertViewType.stars.ratingIcon(index: 2, range: 3), "userpilot_icon_star")
        XCTAssertEqual(LikertViewType.hearts.ratingIcon(index: 0, range: 3), "userpilot_icon_heart")
        XCTAssertNil(LikertViewType.numbers.ratingIcon(index: 0, range: 3))
        for name in ["userpilot_icon_star", "userpilot_icon_heart"] {
            let image = UIImage(named: name, in: Userpilot.resourceBundle, compatibleWith: nil)
            XCTAssertNotNil(image, "\(name) must ship in the bundle")
        }
    }

    func testUnsupportedRangeKeepsTenPointMappingAndNoOverflowImage() {
        XCTAssertEqual(LikertViewType.emojis.ratingIcon(index: 9, range: 11), "userpilot_icon_smile_ten")
        XCTAssertNil(LikertViewType.emojis.ratingIcon(index: 10, range: 11))
    }
}
