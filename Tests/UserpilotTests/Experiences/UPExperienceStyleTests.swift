//
//  UPExperienceStyleTests.swift
//  Userpilot SDK
//
//  Text scaling: opt-in, one body factor for every size, capped at the accessibility-large size.
//

import SwiftUI
import XCTest
@testable import Userpilot

final class UPExperienceStyleTests: XCTestCase {
    private let categories = ContentSizeCategory.allCases

    func testScalingOffPinsEveryCategoryToLarge() {
        for category in categories {
            XCTAssertEqual(UPExperienceStyle.textSize(category, scalingEnabled: false), .large, "\(category)")
        }
    }

    func testScalingOnKeepsSmallerCategoriesAndCapsLargerOnes() {
        let cap = categories.firstIndex(of: .accessibilityLarge) ?? 0
        for (index, category) in categories.enumerated() {
            let expected = index <= cap ? category : .accessibilityLarge
            XCTAssertEqual(UPExperienceStyle.textSize(category, scalingEnabled: true), expected, "\(category)")
        }
    }

    func testFactorIsOneAtLargeAndGrowsWithEachCategory() {
        XCTAssertEqual(UPExperienceStyle.scaledSize(17, for: .large), 17, accuracy: 0.01)
        XCTAssertEqual(UPExperienceStyle.scaledSize(16, for: .large), 16, accuracy: 0.01)
        let sizes = categories.map { UPExperienceStyle.scaledSize(16, for: $0) }
        for (smaller, larger) in zip(sizes, sizes.dropFirst()) {
            XCTAssertGreaterThan(larger, smaller)
        }
    }

    func testResolvedSizesKeepTheirOrderAtEveryCategory() {
        let authored: [CGFloat] = [28, 24, 20, 19, 16, 15, 13]
        for category in categories {
            let capped = UPExperienceStyle.textSize(category, scalingEnabled: true)
            let resolved = authored.map { UPExperienceStyle.scaledSize($0, for: capped) }
            for (larger, smaller) in zip(resolved, resolved.dropFirst()) {
                XCTAssertGreaterThan(larger, smaller, "\(category): \(resolved)")
            }
        }
    }

    func testTheCapIsAboutTwiceTheAuthoredSize() {
        let factor = UPExperienceStyle.scaledSize(17, for: .accessibilityLarge) / 17
        XCTAssertGreaterThan(factor, 1.8)
        XCTAssertLessThanOrEqual(factor, 2.0)
    }

    func testFontKeepsFamilyAndTraitsWhenScaled() {
        let font = UPExperienceStyle.font(
            family: "Serif", size: 16, bold: true, italic: true, category: .accessibilityLarge)
        XCTAssertEqual(font.pointSize, UPExperienceStyle.scaledSize(16, for: .accessibilityLarge), accuracy: 0.01)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
        let serif = UIFont.systemFont(ofSize: 16).fontDescriptor.withDesign(.serif)
            .map { UIFont(descriptor: $0, size: 16) }
        XCTAssertEqual(font.familyName, serif?.familyName)
    }

    func testFontWithoutFamilyStillScalesWhenEnabled() {
        let font = UPExperienceStyle.font(family: nil, size: 16, category: .accessibilityLarge)
        XCTAssertEqual(font.pointSize, UPExperienceStyle.scaledSize(16, for: .accessibilityLarge), accuracy: 0.01)
        XCTAssertGreaterThan(font.pointSize, 16 * 1.7)
        XCTAssertEqual(UPExperienceStyle.font(family: nil, size: 16, category: .large).pointSize, 16, accuracy: 0.01)
    }

    func testEveryCategoryMapsToItsUIKitCategory() {
        let mapped = categories.map(\.uiContentSizeCategory)
        XCTAssertEqual(Set(mapped).count, categories.count)
        XCTAssertEqual(ContentSizeCategory.extraSmall.uiContentSizeCategory, .extraSmall)
        XCTAssertEqual(ContentSizeCategory.large.uiContentSizeCategory, .large)
        XCTAssertEqual(ContentSizeCategory.accessibilityMedium.uiContentSizeCategory, .accessibilityMedium)
        XCTAssertEqual(
            ContentSizeCategory.accessibilityExtraExtraExtraLarge.uiContentSizeCategory,
            .accessibilityExtraExtraExtraLarge)
    }
}
