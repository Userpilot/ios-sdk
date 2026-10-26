//
//  UPRatingItemTests.swift
//  Userpilot SDK
//
//  Pins the rating cells the renderer draws: titles, bundled icon names and tint rules.
//

import XCTest
@testable import Userpilot

final class UPRatingItemTests: XCTestCase {
    func testSmileScalesUseTheNativeAssetNamesInAndroidOrder() throws {
        let suffixes = [
            3: ["three", "five", "nine"],
            5: ["three", "five", "six", "nine", "ten"],
            7: ["one", "three", "five", "six", "seven", "nine", "ten"],
            // Same as Android's RatingItem.getSmileIcon: one to ten, in order.
            10: ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        ]
        for (range, names) in suffixes {
            let items = try step(type: "emojis", range: range).ratingItems
            XCTAssertEqual(items.count, range)
            for (index, suffix) in names.enumerated() {
                XCTAssertEqual(
                    items[index].imageName, "userpilot_icon_smile_\(suffix)", "range \(range) index \(index)")
                XCTAssertEqual(items[index].title, String(index + 1))
                XCTAssertEqual(items[index].type, .emojis)
            }
        }
    }

    func testEveryEmojiCellNamesARealAsset() throws {
        for range in [3, 5, 7, 10] {
            for item in try step(type: "emojis", range: range).ratingItems {
                let name = try XCTUnwrap(item.imageName, "range \(range) cell \(item.title)")
                let image = UIImage(named: name, in: Userpilot.resourceBundle, compatibleWith: nil)
                XCTAssertNotNil(image, "\(name) must ship in the bundle")
            }
        }
    }

    func testStarsHeartsAndNumbersKeepTheirImageRules() throws {
        let stars = try step(type: "stars", range: 3).ratingItems
        XCTAssertTrue(stars.allSatisfy { $0.imageName == "userpilot_icon_star" })
        let hearts = try step(type: "hearts", range: 3).ratingItems
        XCTAssertTrue(hearts.allSatisfy { $0.imageName == "userpilot_icon_heart" })
        XCTAssertTrue(try step(type: "numbers", range: 3).ratingItems.allSatisfy { $0.imageName == nil })
        for name in ["userpilot_icon_star", "userpilot_icon_heart"] {
            let image = UIImage(named: name, in: Userpilot.resourceBundle, compatibleWith: nil)
            XCTAssertNotNil(image, "\(name) must ship in the bundle")
        }
    }

    func testUnsupportedRangeKeepsTenPointMappingAndNoOverflowImage() throws {
        let items = try step(type: "emojis", range: 11).ratingItems
        XCTAssertEqual(items.count, 11)
        XCTAssertNil(items.last?.imageName)
    }

    func testNPSIsZeroToTenNumbers() {
        let items = UPRatingItem.npsScale
        XCTAssertEqual(items.map(\.title), (0...10).map(String.init))
        XCTAssertTrue(items.allSatisfy { $0.imageName == nil && $0.type == .numbers })
    }

    private func step(type: String, range: Int) throws -> SurveyStep {
        let payload: [String: Any] = [
            "id": 1, "type": "likert_scale", "metadata": ["type": type, "range": range]
        ]
        return try JSONDecoder().decode(SurveyStep.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
