//
//  DebuggerFabDockingTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebuggerFabDockingTests: XCTestCase {

    private let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)

    func testInitialOrigin_docksTrailingAtSeventyTwoPercent() {
        let origin = DebuggerFabDocking.initialOrigin(bounds: bounds, safeArea: .zero)

        XCTAssertEqual(origin.x, 390 - 56 - 16)
        XCTAssertEqual(origin.y, (844 * 0.72) - 56)
    }

    func testSnap_docksLeftWhenCenterIsLeftOfMidpoint() {
        let origin = DebuggerFabDocking.snappedOrigin(
            current: CGPoint(x: 40, y: 400),
            bounds: bounds,
            safeArea: .zero
        )

        XCTAssertEqual(origin.x, 16)
        XCTAssertEqual(origin.y, 400)
    }

    func testSnap_docksRightWhenCenterIsRightOfMidpoint() {
        let origin = DebuggerFabDocking.snappedOrigin(
            current: CGPoint(x: 300, y: 400),
            bounds: bounds,
            safeArea: .zero
        )

        XCTAssertEqual(origin.x, 390 - 56 - 16)
        XCTAssertEqual(origin.y, 400)
    }

    func testSnap_clampsYToSafeAreaPlusMargin() {
        let safe = UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)

        let top = DebuggerFabDocking.snappedOrigin(
            current: CGPoint(x: 300, y: 0),
            bounds: bounds,
            safeArea: safe
        )
        XCTAssertEqual(top.y, 47 + 16)

        let bottom = DebuggerFabDocking.snappedOrigin(
            current: CGPoint(x: 300, y: 800),
            bounds: bounds,
            safeArea: safe
        )
        XCTAssertEqual(bottom.y, 844 - 34 - 56 - 16)
    }
}

// swiftlint:enable all
