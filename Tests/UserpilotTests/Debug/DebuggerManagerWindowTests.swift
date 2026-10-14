//
//  DebuggerManagerWindowTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebuggerManagerWindowTests: XCTestCase {

    func testShow_createsStatusBarWindowOnceWithoutBecomingKey() {
        let userpilot = Userpilot(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        )
        let manager = userpilot.container.resolve(DebuggerManaging.self)
            as! DebuggerManager

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
    func testHideStopsRecordingAndSceneActivationCannotReopenTheWindow() {
        let userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-HIDE").defaultInstance(false))
        let manager = DebuggerManager(container: userpilot.container)
        manager.show()
        userpilot.debugEventStore.record(Event(type: .event("old")))

        manager.hide()
        userpilot.debugEventStore.record(Event(type: .event("closed")))
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        XCTAssertNil(manager.debugWindow)
        XCTAssertTrue(userpilot.debugEventStore.events(for: .manual).isEmpty)
        manager.show()
        userpilot.debugEventStore.record(Event(type: .event("new")))
        XCTAssertEqual(userpilot.debugEventStore.events(for: .manual).map(\.title), ["new"])
        manager.hide()
    }

    func testResetClearsHistoryWithoutDisablingAnOpenDebugger() {
        let userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-RESET").defaultInstance(false))
        let manager = DebuggerManager(container: userpilot.container)
        manager.show()
        userpilot.debugEventStore.record(Event(type: .event("old")))
        manager.reset()
        userpilot.debugEventStore.record(Event(type: .event("new")))
        XCTAssertEqual(userpilot.debugEventStore.events(for: .manual).map(\.title), ["new"])
        XCTAssertNotNil(manager.debugWindow)
        manager.hide()
    }

}

// swiftlint:enable all
