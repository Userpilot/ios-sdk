//
//  UserpilotDebuggerManagerWindowTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class UserpilotDebuggerManagerWindowTests: XCTestCase {

    func testShow_createsStatusBarWindowOnceWithoutBecomingKey() {
        let userpilot = Userpilot(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        )
        let manager = userpilot.container.resolve(UserpilotDebuggerManaging.self)
            as! UserpilotDebuggerManager

        manager.show()
        let first = manager.debugWindow
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.windowLevel, .statusBar)
        XCTAssertFalse(first?.isHidden ?? true)
        XCTAssertFalse(first?.isKeyWindow ?? true)
        XCTAssertTrue(first?.isUserpilotWindow ?? false)

        manager.show()
        XCTAssertTrue(first === manager.debugWindow)

        manager.hide()
        XCTAssertTrue(manager.debugWindow?.isHidden ?? true)
    }
}

// swiftlint:enable all
