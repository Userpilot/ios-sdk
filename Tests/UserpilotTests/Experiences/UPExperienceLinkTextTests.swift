//
//  UPExperienceLinkTextTests.swift
//  Userpilot SDK
//
//  The link text view claims touches only on link glyphs and opens links on tap, never on long press.
//

import SwiftUI
import XCTest
@testable import Userpilot

final class UPExperienceLinkTextTests: XCTestCase {
    private let url = URL(string: "https://example.com/privacy")!

    private func makeView() -> (UPExperienceLinkText.LinkTextView, NSRange) {
        let string = NSMutableAttributedString(
            string: "Read our ", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        let linkRange = NSRange(location: string.length, length: ("privacy policy" as NSString).length)
        string.append(NSAttributedString(
            string: "privacy policy", attributes: [.font: UIFont.systemFont(ofSize: 16), .link: url]))
        string.append(NSAttributedString(string: " today.", attributes: [.font: UIFont.systemFont(ofSize: 16)]))
        let view = UPExperienceLinkText.LinkTextView()
        view.attributedText = string
        view.frame = CGRect(x: 0, y: 0, width: 300,
                            height: UPExperienceLinkText.height(of: string, width: 300))
        view.layoutIfNeeded()
        return (view, linkRange)
    }

    func testTouchesLandOnlyOnLinkGlyphs() {
        let (view, linkRange) = makeView()
        let glyphs = view.layoutManager.glyphRange(forCharacterRange: linkRange, actualCharacterRange: nil)
        let linkRect = view.layoutManager.boundingRect(forGlyphRange: glyphs, in: view.textContainer)
        XCTAssertTrue(view.point(inside: CGPoint(x: linkRect.midX, y: linkRect.midY), with: nil))
        XCTAssertEqual(view.link(at: CGPoint(x: linkRect.midX, y: linkRect.midY)), url)
        XCTAssertFalse(view.point(inside: CGPoint(x: 2, y: linkRect.midY), with: nil), "Plain word passes through")
        XCTAssertFalse(view.point(inside: CGPoint(x: 295, y: linkRect.midY), with: nil), "Empty space passes through")
    }

    func testTapOpensTheLinkAndOtherInteractionsAreRefused() {
        let (view, linkRange) = makeView()
        var opened: [URL] = []
        view.openURL = { opened.append($0) }
        XCTAssertFalse(view.textView(view, shouldInteractWith: url, in: linkRange, interaction: .invokeDefaultAction))
        XCTAssertFalse(view.textView(view, shouldInteractWith: url, in: linkRange, interaction: .presentActions))
        XCTAssertFalse(view.textView(view, shouldInteractWith: url, in: linkRange, interaction: .preview))
        XCTAssertEqual(opened, [url])
    }

    func testTextViewIsReadOnlyWithoutInsetsOrScrolling() {
        let (view, _) = makeView()
        XCTAssertFalse(view.isEditable)
        XCTAssertFalse(view.isScrollEnabled)
        XCTAssertEqual(view.textContainerInset, .zero)
        XCTAssertEqual(view.textContainer.lineFragmentPadding, 0)
        // Matches the screenshot of today's UILabel links: link-blue glyphs over a pure blue underline.
        XCTAssertEqual(view.linkTextAttributes[.foregroundColor] as? UIColor, .link)
        XCTAssertEqual(view.linkTextAttributes[.underlineColor] as? UIColor, .blue)
        XCTAssertEqual(view.linkTextAttributes[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
    }
}
