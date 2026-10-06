//
//  RatingItemTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins native rating asset mappings and NPS score selection during model cleanup.
//

import UIKit
import XCTest
@testable import Userpilot

final class RatingItemTests: XCTestCase {
    func testSmileScalesPreserveNativeAssetMappings() throws {
        let suffixes = [
            3: ["three", "five", "nine"],
            5: ["three", "five", "six", "nine", "ten"],
            7: ["one", "three", "five", "six", "seven", "nine", "ten"],
            10: ["one", "two", "three", "four", "five", "six", "seven", "ten", "eight", "ten"]
        ]
        for (range, names) in suffixes {
            let items = RatingItem.fillList(surveyStep: try step(type: "emojis", range: range))
            XCTAssertEqual(items.count, range)
            for (index, suffix) in names.enumerated() {
                // The ten-point scale historically uses this unprefixed asset at index four.
                let name = range == 10 && index == 4 ? "icon_smile_five" : "userpilot_icon_smile_\(suffix)"
                XCTAssertEqual(items[index].image?.pngData(), UIImage.userpilotImage(named: name)?.pngData())
                XCTAssertEqual(items[index].title, String(index + 1))
                XCTAssertFalse(items[index].isSelected)
            }
        }
    }

    func testStarsHeartsAndNumbersKeepTheirImageRules() throws {
        for type in ["stars", "hearts"] {
            let items = RatingItem.fillList(surveyStep: try step(type: type, range: 3))
            let name = type == "stars" ? "userpilot_icon_star" : "userpilot_icon_heart"
            let expected = try XCTUnwrap(UIImage.userpilotImage(named: name))
            XCTAssertTrue(items.allSatisfy { $0.image?.pngData() == expected.pngData() })
        }
        let numbers = RatingItem.fillList(surveyStep: try step(type: "numbers", range: 3))
        XCTAssertTrue(numbers.allSatisfy { $0.image?.size == .zero })
    }

    func testUnsupportedRangeKeepsTenPointMappingAndEmptyOverflowImage() throws {
        let items = RatingItem.fillList(surveyStep: try step(type: "emojis", range: 11))
        XCTAssertEqual(items.count, 11)
        XCTAssertEqual(items.last?.image?.size, .zero)
    }

    func testNPSRetainsZeroBasedTitlesAndSelectionBoundary() {
        let items = RatingItem.fillList(3)
        XCTAssertEqual(items.map(\.title), (0...10).map(String.init))
        XCTAssertEqual(items.filter(\.isSelected).map(\.title), ["0", "1", "2"])
        XCTAssertTrue(items.allSatisfy { $0.image == nil })
    }

    private func step(type: String, range: Int) throws -> SurveyStep {
        let payload: [String: Any] = [
            "id": 1, "type": "likert_scale", "metadata": ["type": type, "range": range]
        ]
        return try JSONDecoder().decode(SurveyStep.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
