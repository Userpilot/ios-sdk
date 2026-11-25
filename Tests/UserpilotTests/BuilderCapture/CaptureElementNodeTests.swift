//
//  CaptureElementNodeTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies Builder wire names and displayed-text snapshots without analytics setup.
//

import XCTest
@testable import Userpilot

final class CaptureElementNodeTests: XCTestCase {
    func testNodeEncodesDisplayedTextInsteadOfSelectorIdentity() throws {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        button.setTitle("Continue", for: .normal)
        button.accessibilityIdentifier = "continue-id"
        button.accessibilityLabel = "Continue to checkout"
        let node = try XCTUnwrap(button.userpilotElementNode())
        button.setTitle("Changed after capture", for: .normal)

        let json = try encode(node)
        XCTAssertEqual(json["target_class"] as? String, String(describing: type(of: button)))
        XCTAssertEqual(json["target_text"] as? String, "Continue")
        XCTAssertNil(json["native_type"])
        XCTAssertNil(json["display_name"])
        let selector = try XCTUnwrap(json["selector"] as? [String: String])
        XCTAssertEqual(selector["accessibility_identifier"], "continue-id")
        XCTAssertEqual(selector["accessibility_label"], "Continue to checkout")
        XCTAssertNil(selector["target_text"])
        XCTAssertEqual((json["bounds"] as? [String: Double])?["width"], 100)
    }

    func testIdentifierOnlyNodeOmitsText() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        view.accessibilityIdentifier = "container-id"
        view.accessibilityLabel = "Accessible description"
        let json = try encode(XCTUnwrap(view.userpilotElementNode()))
        XCTAssertNil(json["target_text"])
        XCTAssertNotNil(json["selector"])
    }

    func testAnalyticsRedactionDoesNotApplyToBuilderText() throws {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        container.userpilotRedactText = true
        let label = UILabel(frame: container.bounds)
        label.text = "Shown label"
        label.userpilotRedactText = true
        container.addSubview(label)
        XCTAssertEqual(try encode(XCTUnwrap(label.userpilotElementNode()))["target_text"] as? String, "Shown label")
    }

    func testSecureInputDescendantDoesNotExposeText() throws {
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        field.isSecureTextEntry = true
        let label = UILabel(frame: field.bounds)
        label.text = "Private input"
        field.addSubview(label)
        XCTAssertNil(try encode(XCTUnwrap(label.userpilotElementNode()))["target_text"])
    }

    func testOnlyTargetableNodesAreEncodedUnderTheRoot() throws {
        let button = node("button", SelectorProperties(accessibilityIdentifier: "buy"), [node("icon")])
        let label = node("label", SelectorProperties(accessibilityLabel: "Total"))
        let root = node("root", nil, [node("decoration"), node("container", nil, [button, label])])

        let json = try encode(root)
        let children = try XCTUnwrap(json["children"] as? [[String: Any]])

        XCTAssertEqual(json["node_id"] as? String, "root", "The root is kept without a selector")
        XCTAssertEqual(children.compactMap { $0["node_id"] as? String }, ["button", "label"])
        XCTAssertNil(children.first?["children"], "A child without a selector is dropped")
    }

    private func node(
        _ nodeID: String, _ selector: SelectorProperties? = nil, _ children: [ElementNode] = []
    ) -> ElementNode {
        ElementNode(nodeID: nodeID, nativeType: "UIView", displayName: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10), visibleBounds: nil,
                    selector: selector, children: children, view: nil)
    }

    private func encode(_ node: ElementNode) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(node)) as? [String: Any])
    }
}
