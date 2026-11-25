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
        XCTAssertEqual(
            first?.rootViewController.flatMap {
                objc_getAssociatedObject($0, &ScreenNameTracker.untrackedScreenKey) as? Bool
            },
            true
        )

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

    func testFloatingExitClearsEveryChannelAndStopsRecordingUntilReopened() throws {
        try assertExitClearsHistory { overlay in
            try self.invokeButton(in: overlay.fabView, label: DebuggerStrings.exitAccessibility)
        }
    }

    func testPanelClosePreservesFloatingControlsAndRecording() throws {
        try assertPanelDismissPreservesHistory { overlay in
            try self.invokeButton(in: overlay, label: DebuggerStrings.closeAccessibility)
        }
    }

    func testOutsideTapPreservesFloatingControlsAndRecording() throws {
        try assertPanelDismissPreservesHistory { overlay in
            let dim = try XCTUnwrap(overlay.hitTest(CGPoint(x: 8, y: 8), with: nil))
            XCTAssertTrue(dim.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } == true)
            overlay.perform(NSSelectorFromString("dimTapped"))
        }
    }

    func testLogoTapOnOpenPanelPreservesFloatingControlsAndRecording() throws {
        try assertPanelDismissPreservesHistory { overlay in
            try self.invokeButton(in: overlay.fabView, label: DebuggerStrings.fabAccessibility)
        }
    }

    private func assertPanelDismissPreservesHistory(close: (DebuggerOverlayView) throws -> Void) throws {
        let userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-PANEL").defaultInstance(false))
        let manager = DebuggerManager(container: userpilot.container)
        defer { manager.hide() }
        manager.show()
        let window = try XCTUnwrap(manager.debugWindow)
        let overlay = try XCTUnwrap(window.rootViewController?.view as? DebuggerOverlayView)
        overlay.layoutIfNeeded()
        overlay.showPanel(animated: false)
        userpilot.debugEventStore.record(Event(type: .event("before")))
        userpilot.debugEventStore.record(Event(type: .autoCaptureEvent))
        userpilot.debugEventStore.record(FlowExperienceActionEvent.seen(flowId: 42))

        try close(overlay)
        manager.onSceneActive()
        userpilot.debugEventStore.record(Event(type: .event("after")))

        XCTAssertTrue(manager.debugWindow === window)
        XCTAssertFalse(window.isHidden)
        XCTAssertTrue(overlay.fabView.host === overlay)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 8, y: 8), with: nil))
        XCTAssertNotNil(overlay.hitTest(overlay.fabView.center, with: nil))
        XCTAssertEqual(userpilot.debugEventStore.events(for: .manual).map(\.title), ["after", "before"])
        XCTAssertEqual(userpilot.debugEventStore.events(for: .autoCapture).count, 1)
        XCTAssertEqual(userpilot.debugEventStore.events(for: .internalSDK).count, 1)

        try invokeButton(in: overlay.fabView, label: DebuggerStrings.fabAccessibility)
        XCTAssertNotNil(overlay.hitTest(CGPoint(x: 8, y: 8), with: nil))
        XCTAssertTrue(manager.debugWindow === window)
    }

    private func assertExitClearsHistory(close: (DebuggerOverlayView) throws -> Void) throws {
        let userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-EXIT").defaultInstance(false))
        let manager = DebuggerManager(container: userpilot.container)
        defer { manager.hide() }
        manager.show()
        userpilot.debugEventStore.record(Event(type: .event("old")))
        userpilot.debugEventStore.record(Event(type: .autoCaptureEvent))
        userpilot.debugEventStore.record(FlowExperienceActionEvent.seen(flowId: 42))
        let overlay = try XCTUnwrap(manager.debugWindow?.rootViewController?.view as? DebuggerOverlayView)
        overlay.layoutIfNeeded()
        overlay.showPanel(animated: false)

        try close(overlay)
        try invokeButton(in: overlay.fabView, label: DebuggerStrings.fabAccessibility)
        manager.onSceneActive()
        userpilot.debugEventStore.record(Event(type: .event("closed")))

        XCTAssertNil(manager.debugWindow)
        for channel in [DebugEventChannel.manual, .autoCapture, .internalSDK] {
            XCTAssertTrue(userpilot.debugEventStore.events(for: channel).isEmpty)
        }
        XCTAssertNil(overlay.fabView.host)
        manager.show()
        XCTAssertNotNil(manager.debugWindow)
        for channel in [DebugEventChannel.manual, .autoCapture, .internalSDK] {
            XCTAssertTrue(userpilot.debugEventStore.events(for: channel).isEmpty)
        }
        userpilot.debugEventStore.record(Event(type: .event("new")))
        XCTAssertEqual(userpilot.debugEventStore.events(for: .manual).map(\.title), ["new"])
    }

    private func invokeButton(in view: UIView, label: String) throws {
        let button = try XCTUnwrap(findButton(in: view, label: label))
        let target = try XCTUnwrap(button.allTargets.first as? NSObject)
        // SPM's hostless runner has no UIApplication action dispatcher. Exercise the registered target/action.
        let action = try XCTUnwrap(button.actions(forTarget: target, forControlEvent: .touchUpInside)?.first)
        XCTAssertTrue(target.responds(to: NSSelectorFromString(action)))
        target.perform(NSSelectorFromString(action), with: button)
    }

    private func findButton(in view: UIView, label: String) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityLabel == label || button.currentTitle == label {
            return button
        }
        return view.subviews.lazy.compactMap { self.findButton(in: $0, label: label) }.first
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

    func testFlowTabShowsLiveStepErrorsAndClearsWhenTheSessionResets() throws {
        let userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-DEBUG-FLOW").defaultInstance(false))
        let manager = DebuggerManager(container: userpilot.container)
        manager.show()
        defer { manager.hide() }
        let overlay = try XCTUnwrap(manager.debugWindow?.rootViewController?.view as? DebuggerOverlayView)
        overlay.layoutIfNeeded()
        overlay.showPanel(animated: false)
        try invokeButton(in: overlay, label: DebuggerStrings.tabFlow)
        let table = try XCTUnwrap(descendants(of: overlay).compactMap { $0 as? UITableView }.first)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)

        let payload = TooltipFixture.flowPayload(types: ["tooltip"])
        let flow = try XCTUnwrap(payload.toJSONString()?.toFlowContent()?.flowContent)
        let step = try XCTUnwrap(flow.steps.first)
        let segment = FlowSegment(flowId: flow.id, stepsCount: 1, screen: "Checkout", run: FlowRun())
        let context = DebugFlowContext(flow: flow, isPreview: false, generation: UUID())
        userpilot.debugEventStore.recordFlow(context, outcome: FlowStepEvents.failed(segment, step, issue: "not_found"),
                                            screen: "Checkout")
        XCTAssertEqual(table.numberOfRows(inSection: 0), 2)
        overlay.layoutIfNeeded()
        let labels = descendants(of: table).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(labels.contains("FLOW 40 · RUN 1 · COMPLETED"))
        XCTAssertTrue(labels.contains("Step 1 of 1 · Tooltip · #401"))
        XCTAssertTrue(labels.contains("Failed\nError: not_found on Checkout"))

        manager.reset()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
        let empty = descendants(of: overlay).compactMap { $0 as? UILabel }
            .first { $0.text == DebuggerStrings.emptyFlows }
        XCTAssertEqual(empty?.isHidden, false)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

}

// swiftlint:enable all
