//
//  LineTextRunsTests.swift
//  Userpilot SDK
//
//  One styling source for flow text: the same runs feed SwiftUI Text and the link UITextView.
//

import SwiftUI
import XCTest
@testable import Userpilot

final class LineTextRunsTests: XCTestCase {
    // Distinct title and body colours so each rule's colour is observable.
    // swiftlint:disable:next force_try
    private let theme = try! JSONDecoder().decode(ExperienceTheme.self, from: JSONSerialization.data(
        withJSONObject: ["colors": ["text_color": "#112233", "title_color": "#445566"]]))

    func testFixtureThemeHasDistinctTitleAndBodyColours() {
        XCTAssertNotEqual(theme.textColor, theme.titleTextColor)
    }

    func testHeadingLevelsUseTheirSizeBoldAndTitleColor() throws {
        for (level, size) in [("h1", 28), ("h2", 24), ("h3", 20)] {
            let run = try XCTUnwrap(line(type: "heading", level: level, [text("Title")]).textRuns(theme: theme).first)
            XCTAssertEqual(run.size, CGFloat(size), level)
            XCTAssertTrue(run.bold)
            XCTAssertEqual(run.color, theme.titleTextColor)
        }
        let unleveled = try XCTUnwrap(line(type: "heading", [text("Title")]).textRuns(theme: theme).first)
        XCTAssertEqual(unleveled.size, CGFloat(ThemeHandler.DefaultValues.headerTextSize))
    }

    func testHeadingIgnoresParagraphMarksButKeepsLinks() throws {
        let runs = line(type: "heading", level: "h2", [
            text("Styled", [
                ["type": "italic"], ["type": "textStyle", "attrs": ["font_size": "40px", "color": "#FF0000"]]
            ]),
            text("Linked", [["type": "link", "attrs": ["href": "https://example.com"]]])
        ]).textRuns(theme: theme)
        XCTAssertEqual(runs[0].size, 24)
        XCTAssertFalse(runs[0].italic)
        XCTAssertEqual(runs[0].color, theme.titleTextColor)
        XCTAssertEqual(runs[1].link, URL(string: "https://example.com"))
        XCTAssertEqual(runs[1].color, UIColor.blue)
    }

    func testParagraphDefaultsToSixteenAndThemeTextColor() throws {
        let run = try XCTUnwrap(line(type: "paragraph", [text("Body")]).textRuns(theme: theme).first)
        XCTAssertEqual(run.size, 16)
        XCTAssertFalse(run.bold)
        XCTAssertFalse(run.italic)
        XCTAssertEqual(run.color, theme.textColor)
        XCTAssertNil(run.link)
    }

    func testParagraphTextStyleMarkSetsSizeAndColor() throws {
        let run = try XCTUnwrap(line(type: "paragraph", [
            text("Body", [["type": "textStyle", "attrs": ["font_size": "20px", "color": "#D32F2F"]]])
        ]).textRuns(theme: theme).first)
        XCTAssertEqual(run.size, 20)
        XCTAssertEqual(run.color, "#D32F2F".color)
    }

    func testBoldAndItalicMarks() throws {
        let runs = line(type: "paragraph", [
            text("Bold", [["type": "bold"]]), text("Italic", [["type": "italic"]]),
            text("Both", [["type": "bold"], ["type": "italic"]])
        ]).textRuns(theme: theme)
        XCTAssertEqual(runs.map(\.bold), [true, false, true])
        XCTAssertEqual(runs.map(\.italic), [false, true, true])
    }

    func testLinkMarkAddsURLAndBlueOnAnyLineType() throws {
        for type in ["paragraph", "icon_bullet_list"] {
            let runs = line(type: type, [
                text("Read "), text("this", [["type": "link", "attrs": ["href": "https://example.com/a"]]])
            ]).textRuns(theme: theme)
            XCTAssertNil(runs[0].link)
            XCTAssertEqual(runs[1].link, URL(string: "https://example.com/a"))
            XCTAssertEqual(runs[1].color, UIColor.blue)
        }
    }

    func testEmptyLinkHrefStaysPlainText() throws {
        let run = try XCTUnwrap(line(type: "paragraph", [
            text("Nowhere", [["type": "link", "attrs": ["href": ""]]])
        ]).textRuns(theme: theme).first)
        XCTAssertNil(run.link)
        XCTAssertEqual(run.color, theme.textColor)
    }

    func testAlignmentDefaultsToCenter() {
        XCTAssertEqual(line(type: "paragraph", [text("x")]).runAlignment, .center)
        XCTAssertEqual(line(type: "paragraph", align: "left", [text("x")]).runAlignment, .left)
        XCTAssertEqual(line(type: "paragraph", align: "right", [text("x")]).runAlignment, .right)
    }

    func testAttributedStringUsesResolvedFontsAndLinkAttributes() throws {
        let runs = line(type: "paragraph", align: "right", [
            text("Read "),
            text("this", [["type": "link", "attrs": ["href": "https://example.com/a"]], ["type": "bold"]])
        ]).textRuns(theme: theme)
        XCTAssertTrue(runs.hasLink)
        for category in [ContentSizeCategory.large, .accessibilityLarge] {
            let string = runs.attributedString(family: nil, category: category, alignment: .right)
            let plainFont = try XCTUnwrap(string.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
            XCTAssertEqual(plainFont.pointSize, UPExperienceStyle.scaledSize(16, for: category), accuracy: 0.01)
            let linkIndex = ("Read " as NSString).length
            XCTAssertEqual(string.attribute(.link, at: linkIndex, effectiveRange: nil) as? URL,
                           URL(string: "https://example.com/a"))
            XCTAssertEqual(string.attribute(.underlineStyle, at: linkIndex, effectiveRange: nil) as? Int,
                           NSUnderlineStyle.single.rawValue)
            let linkFont = try XCTUnwrap(string.attribute(.font, at: linkIndex, effectiveRange: nil) as? UIFont)
            XCTAssertTrue(linkFont.fontDescriptor.symbolicTraits.contains(.traitBold))
            let paragraph = string.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            XCTAssertEqual(paragraph?.alignment, .right)
        }
        XCTAssertFalse(line(type: "paragraph", [text("Plain")]).textRuns(theme: theme).hasLink)
    }
}

private extension LineTextRunsTests {
    func text(_ value: String, _ marks: [[String: Any]] = []) -> [String: Any] {
        ["text": value, "type": "text", "marks": marks]
    }

    func line(type: String, level: String? = nil, align: String? = nil, _ content: [[String: Any]]) -> Line {
        var attrs: [String: Any] = ["__type__": type]
        if let level { attrs["level"] = level }
        if let align { attrs["text_align"] = align }
        let json: [String: Any] = ["type": type, "attrs": attrs, "content": content]
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Line.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
