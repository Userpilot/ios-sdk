//
//  UserpilotLabelAttachmentTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies SwiftUI label attachment cleanup without retaining its UIKit host hierarchy.
//

import XCTest
@testable import Userpilot

final class UserpilotLabelAttachmentTests: XCTestCase {
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
}
