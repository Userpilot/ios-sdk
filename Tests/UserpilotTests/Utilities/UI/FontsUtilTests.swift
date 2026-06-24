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
}
