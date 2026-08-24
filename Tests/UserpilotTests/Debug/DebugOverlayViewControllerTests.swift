//
//  DebugOverlayViewControllerTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugOverlayViewControllerTests: XCTestCase {

    func testLoadView_marksScreenUntrackedAndKeepsStatusBar() {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)
        let controller = DebugOverlayViewController(
            eventStore: store,
            configFactory: StubConfig(),
            userFactory: StubUser()
        )

        _ = controller.view

        XCTAssertEqual(
            objc_getAssociatedObject(controller, &ScreenNameTracker.untrackedScreenKey) as? Bool,
            true
        )
        XCTAssertFalse(controller.prefersStatusBarHidden)
        XCTAssertTrue(controller.view is DebugOverlayView)
    }
}

private final class StubConfig: DebugConfigSnapshotMaking {
    func create() -> DebugSnapshot { DebugSnapshot(sections: []) }
}

private final class StubUser: DebugUserSnapshotMaking {
    func create() -> DebugSnapshot { DebugSnapshot(sections: []) }
}

// swiftlint:enable all
