//
//  FontsUtilTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

@available(iOS 13.0, *)
final class FontsUtilTests: XCTestCase {

    func testFontWeightStringMapping() {
        XCTAssertEqual(UIFont.Weight(string: "Black"), .black)
        XCTAssertEqual(UIFont.Weight(string: "Heavy"), .heavy)
        XCTAssertEqual(UIFont.Weight(string: "Bold"), .bold)
        XCTAssertEqual(UIFont.Weight(string: "Semibold"), .semibold)
        XCTAssertEqual(UIFont.Weight(string: "Medium"), .medium)
        XCTAssertEqual(UIFont.Weight(string: "Regular"), .regular)
        XCTAssertEqual(UIFont.Weight(string: "Light"), .light)
        XCTAssertEqual(UIFont.Weight(string: "Thin"), .thin)
        XCTAssertEqual(UIFont.Weight(string: "Ultralight"), .ultraLight)
        XCTAssertNil(UIFont.Weight(string: "ExtraBold"))
        XCTAssertNil(UIFont.Weight(string: nil))
    }

    func testSystemDesignStringMapping() {
        XCTAssertNotNil(UIFontDescriptor.SystemDesign(string: "Default"))
        XCTAssertNotNil(UIFontDescriptor.SystemDesign(string: "Monospaced"))
        XCTAssertNotNil(UIFontDescriptor.SystemDesign(string: "Rounded"))
        XCTAssertNotNil(UIFontDescriptor.SystemDesign(string: "Serif"))
        XCTAssertNil(UIFontDescriptor.SystemDesign(string: "Sans"))
        XCTAssertNil(UIFontDescriptor.SystemDesign(string: nil))
    }

    func testMatchingWithoutFontNameUsesSystemFontWithRequestedTraits() {
        let font = UIFont.matching(
            fontName: nil,
            fontWeight: [.traitBold],
            fontSize: 17
        )

        XCTAssertGreaterThan(font.pointSize, 0)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testMatchingUnknownFontFallsBackToUsableFont() {
        let font = UIFont.matching(
            fontName: "DefinitelyMissingFont",
            fontWeight: [.traitItalic],
            fontSize: 18
        )

        XCTAssertGreaterThan(font.pointSize, 0)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testNilFontNameKeepsTheRequestedSizeWithoutDynamicScaling() {
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge).performAsCurrent {
            let font = UIFont.matching(fontName: nil, fontWeight: [.traitBold], fontSize: 17)
            XCTAssertEqual(font.pointSize, 17)
            XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        }
    }

    func testNamedFallbackUsesSizeBasedScalingWithTheRequestedTraits() {
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge).performAsCurrent {
            let traits: [UIFontDescriptor.SymbolicTraits] = [.traitBold, .traitItalic]
            let baseFont = UIFont.matching(fontName: nil, fontWeight: traits, fontSize: 20)
            let expected = UIFontMetrics(forTextStyle: .title1).scaledFont(for: baseFont)
            let font = UIFont.matching(fontName: "Missing-Test-Font", fontWeight: traits, fontSize: 20)

            XCTAssertEqual(font.fontName, expected.fontName)
            XCTAssertEqual(font.pointSize, expected.pointSize)
        }
    }

    func testKnownUIKitFontWithoutBundleFileStillUsesSystemFallback() {
        let font = UIFont.matching(fontName: "Courier", fontWeight: [], fontSize: 17)
        let fallback = UIFont.matching(fontName: "Missing-Test-Font", fontWeight: [], fontSize: 17)

        XCTAssertEqual(font.fontName, fallback.fontName)
        XCTAssertEqual(font.pointSize, fallback.pointSize)
    }

    func testSystemDesignRetainsItsDescriptorAndTraits() throws {
        let descriptor = try XCTUnwrap(
            UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.monospaced)
        )
        let boldDescriptor = descriptor.withSymbolicTraits(.traitBold) ?? descriptor
        let expected = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: UIFont(descriptor: boldDescriptor, size: 17)
        )
        let font = UIFont.matching(fontName: "Monospaced", fontWeight: [.traitBold], fontSize: 17)

        XCTAssertEqual(font.fontName, expected.fontName)
        XCTAssertEqual(font.pointSize, expected.pointSize)
    }

    func testTextStyleArgumentRetainsExistingSizeBasedBehavior() {
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge).performAsCurrent {
            let caption = UIFont.matching(fontName: "Default", fontWeight: [], fontSize: 17, textStyle: .caption1)
            let title = UIFont.matching(fontName: "Default", fontWeight: [], fontSize: 17, textStyle: .title1)
            XCTAssertEqual(caption.pointSize, title.pointSize)
        }
    }

    func testMetricsPreserveCaptionBodyAndTitleBoundaries() {
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let cases: [(CGFloat, UIFont.TextStyle)] = [(15, .caption1), (16, .body), (19, .body), (20, .title1)]
        for (size, style) in cases {
            let baseFont = UIFont.systemFont(ofSize: size)
            let actual = UIFontMetrics.metricFor(size: size).scaledFont(for: baseFont, compatibleWith: traits)
            let expected = UIFontMetrics(forTextStyle: style).scaledFont(for: baseFont, compatibleWith: traits)
            XCTAssertEqual(actual.pointSize, expected.pointSize, "Size \(size)")
        }
    }
}
