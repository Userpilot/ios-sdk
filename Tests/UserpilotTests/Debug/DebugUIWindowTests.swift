//
//  DebugUIWindowTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugUIWindowTests: XCTestCase {

    func testIsUserpilotWindow_isTrueForDebugUIWindow() {
        let window = DebugUIWindow(
            root: UIViewController(),
            windowScene: UIApplication.shared.connectedScenes.first as? UIWindowScene
        )
        defer { window.isHidden = true }

        XCTAssertTrue(window.isUserpilotWindow)
        XCTAssertFalse(UIWindow().isUserpilotWindow)
        XCTAssertEqual(window.windowLevel, .statusBar)
        XCTAssertFalse(window.isHidden)
        XCTAssertFalse(window.isKeyWindow)
    }

    func testHitTest_returnsNilForEmptyRoot() {
        let root = UIViewController()
        root.view.backgroundColor = .clear
        let window = DebugUIWindow(
            root: root,
            windowScene: UIApplication.shared.connectedScenes.first as? UIWindowScene
        )
        defer { window.isHidden = true }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.layoutIfNeeded()

        XCTAssertNil(window.hitTest(CGPoint(x: 10, y: 10), with: nil))
    }

    func testHitTest_topTrailingPassesThroughWhenCollapsed() {
        let overlay = makeOverlay()
        let host = UIViewController()
        host.view = overlay
        let window = DebugUIWindow(
            root: host,
            windowScene: UIApplication.shared.connectedScenes.first as? UIWindowScene
        )
        defer { window.isHidden = true }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        overlay.frame = window.bounds
        overlay.layoutIfNeeded()

        XCTAssertNil(window.hitTest(CGPoint(x: 370, y: 54), with: nil))
        let fabHit = window.hitTest(overlay.fabView.center, with: nil)
        XCTAssertTrue(fabHit === overlay.fabView || fabHit?.isDescendant(of: overlay.fabView) == true)
    }

    private func makeOverlay() -> DebugOverlayView {
        let bus = DebugEventBus()
        let store = DebugEventStore(bus: bus)
        store.start()
        return DebugOverlayView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            eventStore: store,
            configFactory: WindowStubConfig(),
            userFactory: WindowStubUser()
        )
    }
}

private final class WindowStubConfig: DebugConfigSnapshotMaking {
    func create() -> DebugSnapshot { DebugSnapshot(sections: []) }
}

private final class WindowStubUser: DebugUserSnapshotMaking {
    func create() -> DebugSnapshot { DebugSnapshot(sections: []) }
}

// swiftlint:enable all
