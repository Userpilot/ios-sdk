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

    func testLookupWithoutFontNameUsesSystemFontWithRequestedTraits() {
        let font = UIFont.lookup(fontName: nil, fontWeight: [.traitBold], fontSize: 17)

        XCTAssertGreaterThan(font.pointSize, 0)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testLookupUnknownFontFallsBackToUsableFont() {
        let font = UIFont.lookup(fontName: "DefinitelyMissingFont", fontWeight: [.traitItalic], fontSize: 18)

        XCTAssertGreaterThan(font.pointSize, 0)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    /// The renderer scales sizes itself, so a second scale here would double the text size.
    func testLookupIgnoresTheSystemTextSize() {
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge).performAsCurrent {
            XCTAssertEqual(UIFont.lookup(fontName: nil, fontWeight: [.traitBold], fontSize: 17).pointSize, 17)
            XCTAssertEqual(UIFont.lookup(fontName: "Missing-Test-Font", fontWeight: [], fontSize: 20).pointSize, 20)
            XCTAssertEqual(UIFont.lookup(fontName: "Monospaced", fontWeight: [], fontSize: 13).pointSize, 13)
        }
    }

    func testKnownUIKitFontWithoutBundleFileStillUsesSystemFallback() {
        let font = UIFont.lookup(fontName: "Courier", fontWeight: [], fontSize: 17)
        let fallback = UIFont.lookup(fontName: "Missing-Test-Font", fontWeight: [], fontSize: 17)

        XCTAssertEqual(font.fontName, fallback.fontName)
        XCTAssertEqual(font.pointSize, fallback.pointSize)
    }

    func testSystemDesignRetainsItsDescriptorAndTraits() throws {
        let descriptor = try XCTUnwrap(
            UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.monospaced)
        )
        let boldDescriptor = descriptor.withSymbolicTraits(.traitBold) ?? descriptor
        let expected = UIFont(descriptor: boldDescriptor, size: 17)
        let font = UIFont.lookup(fontName: "Monospaced", fontWeight: [.traitBold], fontSize: 17)

        XCTAssertEqual(font.fontName, expected.fontName)
        XCTAssertEqual(font.pointSize, expected.pointSize)
    }
}
