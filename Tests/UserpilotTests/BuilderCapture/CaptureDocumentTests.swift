//
//  CaptureDocumentTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins the capture.json fields: link capture id, typed display name, the screen object and file name.
//

import XCTest
@testable import Userpilot

final class CaptureDocumentTests: XCTestCase {

    func testDocumentCarriesTheLinkCaptureIDAndTheScreenshotFileName() throws {
        let json = try encode(CaptureFixture.make(captureID: "cap-from-link").document)

        XCTAssertEqual(json["schema_version"] as? Int, 1)
        XCTAssertEqual(json["capture_id"] as? String, "cap-from-link")
        let screenshot = try XCTUnwrap(json["screenshot"] as? [String: Any])
        XCTAssertEqual(screenshot["file_name"] as? String, "screenshot.png")
        XCTAssertEqual(screenshot["format"] as? String, "png")
        XCTAssertNil(screenshot["url"])
    }

    func testDisplayNameIsTheTypedNameTrimmedAndCappedAtCodePoints() throws {
        let document = CaptureFixture.make(captureID: "cap-name").document
        XCTAssertEqual(try encode(document.named("  Checkout  "))["display_name"] as? String, "Checkout")

        // 254 + 2 code points: the skin-tone modifier is the 256th, so it is cut though the emoji is one Character.
        let typed = String(repeating: "a", count: 254) + "👍🏽"
        let capped = try XCTUnwrap(try encode(document.named(typed))["display_name"] as? String)
        XCTAssertEqual(capped.unicodeScalars.count, 255)
        XCTAssertEqual(capped, String(repeating: "a", count: 254) + "👍")
    }

    func testBlankTypedNameKeepsTheSuggestedName() {
        let document = CaptureFixture.make(captureID: "cap-blank", screen: Event(type: .screen("Checkout"))).document

        XCTAssertEqual(document.displayName, "Checkout", "The screen title is the suggestion")
        XCTAssertEqual(document.named("   ").displayName, "Checkout")
    }

    func testScreenIsTheScreenEventObjectPlusItsName() throws {
        let event = Event(type: .screen("Checkout"), properties: ["source": "manual", "step": 2])
        let json = try encode(CaptureFixture.make(captureID: "cap-screen", screen: event).document)

        let screen = try XCTUnwrap(json["screen"] as? [String: Any])
        XCTAssertEqual(Set(screen.keys), ["name", "title", "metadata"])
        XCTAssertEqual(screen["title"] as? String, "Checkout")
        XCTAssertEqual(screen["name"] as? String, "Checkout")
        XCTAssertEqual(screen["metadata"] as? NSDictionary, ["source": "manual", "step": 2])
    }

    func testScreenNameIsCutAtTheLimitWhileTheTitleIsUnchanged() throws {
        let title = String(repeating: "t", count: 300)
        let json = try encode(CaptureFixture.make(captureID: "cap-long", screen: Event(type: .screen(title))).document)

        let screen = try XCTUnwrap(json["screen"] as? [String: Any])
        XCTAssertEqual(screen["title"] as? String, title)
        XCTAssertEqual(screen["name"] as? String, String(repeating: "t", count: 255))
    }

    func testScreenNameKeepsTheTitleUntrimmedWhileTheSuggestedDisplayNameIsTrimmed() {
        let padded = CaptureFixture.make(captureID: "cap-padded", screen: Event(type: .screen("  Checkout  "))).document

        XCTAssertEqual(padded.screen.name, "  Checkout  ")
        XCTAssertEqual(padded.displayName, "Checkout")
    }

    func testOffScreenNodeHasNoVisibleBounds() throws {
        let frame = CGRect(x: 0, y: 900, width: 10, height: 10)
        let offScreen = ElementNode(
            nodeID: "below-fold", nativeType: "UIButton", displayName: nil, bounds: frame, visibleBounds: nil,
            selector: SelectorProperties(accessibilityIdentifier: "below-fold"), children: [], view: nil)
        let visible = ElementNode(
            nodeID: "visible", nativeType: "UIButton", displayName: nil, bounds: .zero, visibleBounds: .zero,
            selector: SelectorProperties(accessibilityIdentifier: "visible"), children: [], view: nil)
        let root = ElementNode(nodeID: "root", nativeType: "UIWindow", displayName: nil, bounds: .zero,
                               visibleBounds: .zero, selector: nil, children: [offScreen, visible], view: nil)

        let json = try encode(CaptureFixture.make(captureID: "cap-tree", tree: root).document)

        let children = try XCTUnwrap((json["element_tree"] as? [String: Any])?["children"] as? [[String: Any]])
        XCTAssertEqual(children.count, 2)
        XCTAssertNil(children[0]["visible_bounds"])
        XCTAssertNotNil(children[1]["visible_bounds"])
    }

    func testNoTokenOrURLAnywhereInTheDocument() throws {
        let link = try XCTUnwrap(CaptureLink.from(captureID: "cap-secret", platform: "ios", token: "secret-token"))
        let document = CaptureFixture.make(captureID: link.captureID).document
        let text = try XCTUnwrap(String(data: JSONEncoder().encode(document), encoding: .utf8))

        XCTAssertFalse(text.contains("secret-token"))
        XCTAssertFalse(text.contains("appex.userpilot.io"))
    }

    private func encode(_ document: CaptureDocument) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
    }
}
