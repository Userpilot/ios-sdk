//
//  UserpilotLabelAttachmentTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies SwiftUI label attachment cleanup without retaining its UIKit host hierarchy,
//  and that `userpilotLabel` analytics text and `userpilotTarget` identity stay independent.
//

import SwiftUI
import XCTest
@testable import Userpilot

final class UserpilotLabelAttachmentTests: XCTestCase {
    func testLabel_setsTargetTextAndNoUserpilotID() throws {
        let label = try hierarchySnapshot(.label)

        XCTAssertEqual(label.userpilotIDs, [])
        XCTAssertEqual(label.labeledHosts.count, 1)
        XCTAssertEqual(label.tapPayload[Constants.AutoCapture.targetText] as? String, "Save profile")
        XCTAssertEqual(label.tapPayload[Constants.AutoCapture.targetClass] as? String, "Button")
        XCTAssertEqual(label.carriers, 1)
        XCTAssertEqual(label.markers, 0)
    }

    func testTarget_setsUserpilotIDAndNoTargetText() throws {
        let target = try hierarchySnapshot(.target)

        XCTAssertEqual(target.userpilotIDs, ["profile_save"])
        let anchor = try XCTUnwrap(target.anchors.first)
        XCTAssertEqual(anchor.width, 120, accuracy: 1)
        XCTAssertEqual(anchor.height, 44, accuracy: 1)
        XCTAssertEqual(target.labeledHosts, [])
        XCTAssertNotEqual(target.tapPayload[Constants.AutoCapture.targetText] as? String, "profile_save")
        XCTAssertEqual(target.carriers, 0)
        XCTAssertEqual(target.markers, 1)
    }

    func testLabelAndTargetCombined_giveBothWithoutChangingEitherHost() throws {
        let label = try hierarchySnapshot(.label)
        let target = try hierarchySnapshot(.target)

        for mode in [LabelTargetFixture.Mode.labelThenTarget, .targetThenLabel] {
            let combined = try hierarchySnapshot(mode)
            XCTAssertEqual(combined.userpilotIDs, ["profile_save"], "\(mode)")
            XCTAssertEqual(combined.anchors, target.anchors, "\(mode)")
            XCTAssertEqual(combined.labeledHosts, label.labeledHosts, "\(mode)")
            XCTAssertEqual(combined.tapPayload[Constants.AutoCapture.targetText] as? String, "Save profile", "\(mode)")
            XCTAssertEqual(combined.tapPayload[Constants.AutoCapture.targetClass] as? String, "Button", "\(mode)")
            XCTAssertEqual(combined.carriers, 1, "\(mode)")
            XCTAssertEqual(combined.markers, 1, "\(mode)")
        }
    }

    func testRedactedLabelAndTarget_redactTheLabelOnly() throws {
        let combined = try hierarchySnapshot(.labelThenTarget, redactsText: true)

        XCTAssertEqual(
            combined.tapPayload[Constants.AutoCapture.targetText] as? String,
            Constants.AutoCapture.reductText
        )
        XCTAssertEqual(combined.userpilotIDs, ["profile_save"])
    }

    func testBlankTarget_attachesNothing() throws {
        let host = UIHostingController(rootView: VStack(spacing: 10) {
            Color.clear.frame(height: 120)
            Button("Empty") {}.frame(width: 120, height: 44).userpilotTarget("")
            Button("Whitespace") {}.frame(width: 120, height: 44).userpilotTarget(" \n ")
            Button("Targeted") {}.frame(width: 120, height: 44).userpilotTarget("control")
            Spacer()
        }.frame(width: 300, height: 600).edgesIgnoringSafeArea(.all))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()

        XCTAssertEqual(userpilotIDs(in: try XCTUnwrap(window.userpilotElementNode())), ["control"])
        XCTAssertTrue(descendants(of: host.view).allSatisfy { $0.userpilotLabel == nil })
    }

    func testLabelCarrier_givesAnalyticsMetadataButNoUserpilotID() throws {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let target = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        target.text = "Automatic"
        parent.addSubview(target)
        let carrier = LabelCarrierView()
        carrier.frame = parent.bounds
        parent.addSubview(carrier)
        carrier.setLabel("Submit order", viewType: "Button")

        XCTAssertEqual(target.resolveUserpilotLabel(), "Submit order")
        let payload = target.buildWindowInteractionProperties(at: .zero, in: UIWindow())
        XCTAssertEqual(payload[Constants.AutoCapture.targetText] as? String, "Submit order")
        XCTAssertEqual(payload[Constants.AutoCapture.targetClass] as? String, "Button")
        let tree = try XCTUnwrap(parent.userpilotElementNode())
        XCTAssertEqual(tree.children.count, 2, "The carrier is still in the tree")
        XCTAssertEqual(userpilotIDs(in: tree), [])
    }

    func testRedactedLabelDoesNotFallThroughToAutomaticText() {
        let target = UILabel()
        target.text = "Automatic"
        let carrier = LabelCarrierView()
        target.addSubview(carrier)
        carrier.setLabel("Submit order", viewType: "Button")
        target.userpilotRedactText = true

        let payload = target.buildWindowInteractionProperties(at: .zero, in: UIWindow())

        XCTAssertEqual(payload[Constants.AutoCapture.targetText] as? String, Constants.AutoCapture.reductText)
    }

    func testNilLabelClearsPreviouslyAppliedMetadata() {
        let parent = UIView()
        let target = UILabel()
        let carrier = LabelCarrierView()
        parent.addSubview(target)
        parent.addSubview(carrier)
        carrier.setLabel("Account", viewType: "Text")

        XCTAssertEqual(target.userpilotLabel, "Account")
        carrier.setLabel(nil, viewType: "Text")

        XCTAssertNil(target.userpilotLabel)
        XCTAssertNil(target.userpilotLabelViewType)
    }

    func testReparentWithUnchangedLabelMovesMetadataToNewHost() {
        let firstParent = UIView()
        let secondParent = UIView()
        let firstTarget = UILabel()
        let secondTarget = UILabel()
        let carrier = LabelCarrierView()
        firstParent.addSubview(firstTarget)
        firstParent.addSubview(carrier)
        secondParent.addSubview(secondTarget)
        carrier.setLabel("Account", viewType: "Text")

        secondParent.addSubview(carrier)

        XCTAssertNil(firstTarget.userpilotLabel)
        XCTAssertEqual(secondTarget.userpilotLabel, "Account")
        carrier.removeFromSuperview()
        XCTAssertNil(secondTarget.userpilotLabel)
    }

    func testReparentAndReplacementOnTaggableAncestorsClearOnlyTheirOwnAttachment() {
        let first = UIControl()
        let second = UIControl()
        let carrier = LabelCarrierView()
        first.addSubview(carrier)
        carrier.setLabel("Save", viewType: "Button")
        second.addSubview(carrier)
        XCTAssertNil(first.userpilotLabel)
        XCTAssertEqual(second.userpilotLabel, "Save")
        let replacement = LabelCarrierView()
        second.addSubview(replacement)
        replacement.setLabel("Next", viewType: "Button")
        carrier.removeFromSuperview()
        XCTAssertEqual(second.userpilotLabel, "Next")
        replacement.setLabel(nil, viewType: "Button")
        XCTAssertNil(second.userpilotLabel)
    }

    func testRemovingOldCarrierPreservesReplacementWithSameLabel() {
        let parent = UIView()
        let target = UILabel()
        let oldCarrier = LabelCarrierView()
        let replacement = LabelCarrierView()
        parent.addSubview(target)
        parent.addSubview(oldCarrier)
        oldCarrier.setLabel("Account", viewType: "Text")
        parent.addSubview(replacement)
        replacement.setLabel("Account", viewType: "Text")

        oldCarrier.removeFromSuperview()

        XCTAssertEqual(target.userpilotLabel, "Account")
        XCTAssertEqual(target.userpilotLabelViewType, "Text")
        replacement.removeFromSuperview()
        XCTAssertNil(target.userpilotLabel)
    }

    func testCarrierDoesNotRetainItsFallbackParent() {
        weak var retainedParent: UIView?
        weak var retainedCarrier: LabelCarrierView?
        autoreleasepool {
            let parent = UIView()
            let carrier = LabelCarrierView()
            parent.addSubview(carrier)
            carrier.setLabel("Container", viewType: "VStack")
            XCTAssertEqual(parent.userpilotLabel, "Container")
            retainedParent = parent
            retainedCarrier = carrier
        }

        XCTAssertNil(retainedParent)
        XCTAssertNil(retainedCarrier)
    }

    func testSiblingTargetWinsBeforeTaggableAncestor() {
        let parent = UIControl()
        let sibling = UILabel()
        let carrier = LabelCarrierView()
        parent.addSubview(sibling)
        parent.addSubview(carrier)

        carrier.setLabel("Sibling", viewType: "Text")

        XCTAssertEqual(sibling.userpilotLabel, "Sibling")
        XCTAssertNil(parent.userpilotLabel)
    }

    // MARK: - Helpers

    private struct HierarchySnapshot {
        let userpilotIDs: [String]
        let anchors: [CGRect]
        let labeledHosts: [CGRect]
        let tapPayload: [String: Any]
        let carriers: Int
        let markers: Int
    }

    private func hierarchySnapshot(
        _ mode: LabelTargetFixture.Mode,
        redactsText: Bool = false
    ) throws -> HierarchySnapshot {
        let host = UIHostingController(rootView: LabelTargetFixture(mode: mode))
        host.view.userpilotRedactText = redactsText
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()
        let views = descendants(of: host.view)
        let tree = try XCTUnwrap(window.userpilotElementNode())
        func anchors(_ node: ElementNode) -> [CGRect] {
            let own = node.selector?.toMap()["userpilot_id"] == "profile_save" ? [node.bounds] : []
            return own + node.children.flatMap(anchors)
        }
        let centre = LabelTargetFixture.componentCentre
        let touched = try XCTUnwrap(window.hitTest(centre, with: nil) ?? host.view)
        return HierarchySnapshot(
            userpilotIDs: userpilotIDs(in: tree),
            anchors: anchors(tree),
            labeledHosts: views.filter { $0.userpilotLabel != nil }.map { $0.convert($0.bounds, to: nil) },
            tapPayload: touched.buildWindowInteractionProperties(at: centre, in: window),
            carriers: views.filter { $0 is LabelCarrierView }.count,
            markers: views.filter { $0 is UserpilotTargetView }.count
        )
    }

    private func descendants(of view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }

    private func userpilotIDs(in node: ElementNode) -> [String] {
        (node.selector?.toMap()["userpilot_id"].map { [$0] } ?? []) + node.children.flatMap { userpilotIDs(in: $0) }
    }
}

/// One 120×44 button carrying each combination of the public label and target modifiers.
private struct LabelTargetFixture: View {
    enum Mode { case label, target, labelThenTarget, targetThenLabel }

    /// Window point at the middle of the button.
    static let componentCentre = CGPoint(x: 150, y: 152)

    let mode: Mode

    var body: some View {
        VStack(spacing: 10) {
            // Keep the target below the device safe area; off-safe-area identities are intentionally pruned.
            Color.clear.frame(height: 120)
            component
            Text("Sibling")
            Spacer()
        }
        .frame(width: 300, height: 600)
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder private var component: some View {
        switch mode {
        case .label:
            button.userpilotLabel("Save profile")
        case .target:
            button.userpilotTarget("profile_save")
        case .labelThenTarget:
            button.userpilotLabel("Save profile").userpilotTarget("profile_save")
        case .targetThenLabel:
            button.userpilotTarget("profile_save").userpilotLabel("Save profile")
        }
    }

    private var button: some View {
        Button("Automatic") {}.frame(width: 120, height: 44)
    }
}
