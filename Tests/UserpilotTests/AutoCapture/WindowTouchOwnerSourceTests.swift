//
//  WindowTouchOwnerSourceTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The window touch hook's choice of owner-resolution source and captured view. UITouch cannot
//  be constructed, so these drive the hook's own selection step with a real hit test.
//

import XCTest
@testable import Userpilot

final class WindowTouchOwnerSourceTests: InstanceResolverTestCase {

    private var window: UIWindow!
    private var button: UIView!
    private var label: UILabel!
    private let point = CGPoint(x: 60, y: 130)

    override func setUp() {
        super.setUp()
        window = makeWindow()
        window.isHidden = false
        // A tappable container whose title label does not take touches, as in a custom button.
        button = UIView(frame: CGRect(x: 20, y: 100, width: 200, height: 60))
        label = UILabel(frame: CGRect(x: 10, y: 10, width: 120, height: 40))
        label.text = "Pay"
        button.addSubview(label)
        window.addSubview(button)
    }

    override func tearDown() {
        label = nil
        button = nil
        window = nil
        super.tearDown()
    }

    func testWithoutBindingsOrClaims_ownerUsesTheHitView_andTheTapReportsTheInnermostLabel() {
        startWithoutAttachments()
        let host = register("HOST", isDefault: true)
        let hitView = window.hitTest(point, with: nil)
        XCTAssertTrue(hitView === button, "Precondition: UIKit hit-tests the interactive container")

        for phase in [UITouch.Phase.began, .ended] {
            let source = window.touchOwnerSource(hitView: hitView, at: point, phase: phase, resolver: resolver)

            XCTAssertTrue(source.view === button, "No owner can differ, so the innermost walk is skipped")
            XCTAssertTrue(resolver.resolveOwner(from: source.view) === host)
            XCTAssertTrue(window.capturedTapView(hitView: button, source: source, at: point) === label,
                          "A captured tap must describe the innermost view under the finger")
        }
    }

    func testBindingOnTheInnermostView_ownsTheTap_andTheTapReportsThatView() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR")
        vendor.attachToView(label)
        let hitView = window.hitTest(point, with: nil)

        for phase in [UITouch.Phase.began, .ended] {
            let source = window.touchOwnerSource(hitView: hitView, at: point, phase: phase, resolver: resolver)

            XCTAssertTrue(source.view === label)
            XCTAssertTrue(resolver.resolveOwner(from: source.view) === vendor,
                          "The binding on the view under the finger decides the tap's owner")
            XCTAssertTrue(window.capturedTapView(hitView: button, source: source, at: point) === label)
        }
    }

    func testMovingTouch_resolvesFromTheHitViewOnly() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR")
        vendor.attachToView(label)
        XCTAssertTrue(resolver.sourceAffectsOwner)

        let source = window.touchOwnerSource(hitView: button, at: point, phase: .moved, resolver: resolver)

        XCTAssertTrue(source.view === button, "Only tap boundaries pay for the innermost walk")
        XCTAssertTrue(window.capturedTapView(hitView: button, source: source, at: point) === label)
    }
}
