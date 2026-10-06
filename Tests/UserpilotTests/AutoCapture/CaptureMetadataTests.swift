//
//  CaptureMetadataTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins native payload fields, fallback laziness and ancestor-search boundaries.
//

import XCTest
@testable import Userpilot

final class CaptureMetadataTests: XCTestCase {
    func testActionPayloadRetainsExactNativeFields() {
        let label = UILabel()
        label.text = "Continue"
        let payload = label.buildActionInteractionPayload(
            action: NSSelectorFromString("continueTapped:"), target: nil
        )

        XCTAssertEqual(payload.toDictionary() as NSDictionary, [
            Constants.AutoCapture.targetClass: "UILabel",
            Constants.AutoCapture.targetText: "Continue",
            Constants.AutoCapture.targetAction: "continueTapped:",
            Constants.AutoCapture.hierarchy: "UILabel:attr__index=\"0\""
        ] as NSDictionary)
    }

    func testWindowPayloadRetainsExactNativeFields() {
        let label = UILabel()
        label.text = "Continue"
        let payload = label.buildWindowInteractionProperties(at: .zero, in: UIWindow())

        XCTAssertEqual(payload as NSDictionary, [
            Constants.AutoCapture.targetClass: "UILabel",
            Constants.AutoCapture.targetText: "Continue",
            Constants.AutoCapture.hierarchy: "UILabel:attr__index=\"0\""
        ] as NSDictionary)
    }

    func testListLabelSkipsFallbackAndAppliesTouchedViewPrivacy() {
        let cell = UITableViewCell()
        let touched = UILabel()
        cell.contentView.addSubview(touched)
        touched.userpilotLabel = "Private label"
        touched.userpilotLabelViewType = "Text"
        touched.userpilotRedactText = true
        var payload = InteractionPayload(interactionType: .tableViewCellSelected, elementType: "UITableViewCell")
        var fallbackRead = false

        cell.completeListInteractionPayload(&payload, touchedView: touched) {
            fallbackRead = true
            return "Fallback"
        }

        XCTAssertFalse(fallbackRead)
        XCTAssertEqual(payload.targetClass, "Text")
        XCTAssertEqual(payload.elementText, Constants.AutoCapture.reductText)
        XCTAssertNil(payload.accessibilityIdentifier)
    }

    func testAncestorLookupIncludesSelfButParentControlExcludesSelf() {
        let outer = UIControl()
        let inner = UIControl()
        outer.addSubview(inner)

        XCTAssertTrue(inner.firstAncestor(of: UIControl.self) === inner)
        XCTAssertTrue(inner.findParentControl() === outer)
        XCTAssertNil(outer.findParentControl())
    }
}
