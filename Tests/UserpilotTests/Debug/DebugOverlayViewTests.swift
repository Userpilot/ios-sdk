//
//  DebugOverlayViewTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugOverlayViewTests: XCTestCase {

    func testHitTest_collapsedOnlyHitsFab() {
        let overlay = makeOverlay()
        overlay.layoutIfNeeded()

        let fabHit = overlay.hitTest(overlay.fabView.center, with: nil)
        XCTAssertNotNil(fabHit)
        XCTAssertTrue(fabHit === overlay.fabView || fabHit?.isDescendant(of: overlay.fabView) == true)

        XCTAssertNil(overlay.hitTest(CGPoint(x: 8, y: 8), with: nil))
    }

    func testHitTest_expandedHitsDimAndKeepsFab() {
        let overlay = makeOverlay()
        overlay.layoutIfNeeded()
        overlay.showPanel(animated: false)

        XCTAssertNotNil(overlay.hitTest(CGPoint(x: 8, y: 8), with: nil))
        let fabHit = overlay.hitTest(overlay.fabView.center, with: nil)
        XCTAssertTrue(fabHit === overlay.fabView || fabHit?.isDescendant(of: overlay.fabView) == true)
    }

    func testShowHidePanel_doesNotMoveFab() {
        let overlay = makeOverlay()
        overlay.layoutIfNeeded()
        let before = overlay.fabView.frame

        overlay.showPanel(animated: false)
        XCTAssertEqual(overlay.fabView.frame, before)

        overlay.hidePanel(animated: false)
        XCTAssertEqual(overlay.fabView.frame, before)
    }

    private func makeOverlay() -> DebugOverlayView {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)
        store.start()
        let overlay = DebugOverlayView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            eventStore: store,
            configFactory: StubDebugConfigFactory(),
            userFactory: StubDebugUserFactory()
        )
        return overlay
    }
}

private final class StubDebugConfigFactory: DebugConfigSnapshotMaking {
    func create() -> DebugSnapshot {
        DebugSnapshot(sections: [DebugSection(title: "SDK", rows: [DebugProperty(key: "token", value: "NX-1")])])
    }
}

private final class StubDebugUserFactory: DebugUserSnapshotMaking {
    func create() -> DebugSnapshot {
        DebugSnapshot(sections: [])
    }
}

// swiftlint:enable all
