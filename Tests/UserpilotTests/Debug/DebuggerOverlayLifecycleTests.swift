//
//  DebuggerOverlayLifecycleTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebuggerOverlayLifecycleTests: XCTestCase {

    func testRapidHideAndShow_keepsReopenedPanelInteractiveAfterAnimationsFinish() throws {
        let overlay = makeOverlay()
        let window = UIWindow(frame: overlay.bounds)
        let controller = UIViewController()
        controller.view = overlay
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        overlay.layoutIfNeeded()
        overlay.showPanel(animated: false)
        overlay.hidePanel(animated: true)
        overlay.showPanel(animated: true)
        let finished = expectation(description: "panel fades completed")
        let marker = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        window.addSubview(marker)
        UIView.animate(withDuration: DebuggerTheme.fadeDuration * 2, animations: {
            marker.alpha = 0
        }, completion: { _ in finished.fulfill() })
        wait(for: [finished], timeout: 2)

        let panel = try XCTUnwrap(overlay.subviews.first { $0 is DebuggerPanelView })
        XCTAssertTrue(panel.isUserInteractionEnabled)
        XCTAssertEqual(panel.alpha, 1)
        XCTAssertNotNil(overlay.hitTest(CGPoint(x: 8, y: 8), with: nil))
    }

    func testWindowHide_removesPanelObserversEvenIfAViewIsStillRetained() throws {
        let store = ObserverTrackingStore()
        let host = DebugWindowHost(
            eventStore: store, configFactory: StubDebugConfigFactory(), userFactory: StubDebugUserFactory()
        )
        host.show()
        let overlay = try XCTUnwrap(host.debugWindow?.rootViewController?.view as? DebuggerOverlayView)
        overlay.showPanel(animated: false)
        XCTAssertEqual(store.observers.count, 4)

        host.hide()

        XCTAssertTrue(store.observers.isEmpty)
        XCTAssertNil(overlay.fabView.host)
        XCTAssertNil(host.debugWindow)
    }

    private func makeOverlay() -> DebuggerOverlayView {
        let store = DebugEventStore()
        store.start()
        let overlay = DebuggerOverlayView(
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

/// Records nothing but the observers still registered, so a test can check that hiding removes them all.
private final class ObserverTrackingStore: DebugEventStoring {
    var observers = Set<UUID>()
    func start() {}
    func stop() {}
    func reset() {}
    func record(_ event: Event) {}
    func record(_ event: SDKEvent) {}
    func recordPreview(_ event: SDKEvent) {}
    var flowRuns: [DebugFlowRun] { [] }
    func recordFlow(_ context: DebugFlowContext, outcome: FlowStepOutcome?, screen: String?) {}
    func pauseFlow(operationID: UUID) {}
    func events(for channel: DebugEventChannel) -> [DebugEvent] { [] }
    func observe(_ channel: DebugEventChannel, handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers.insert(id)
        handler()
        return id
    }
    func removeObserver(_ id: UUID) { observers.remove(id) }
}

// swiftlint:enable all
