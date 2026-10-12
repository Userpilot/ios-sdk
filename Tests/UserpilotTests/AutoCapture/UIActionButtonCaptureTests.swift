//
//  UIActionButtonCaptureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 12/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises UIKit's real closure-action dispatch and the existing capture/privacy pipeline.
//

import XCTest
@testable import Userpilot

@available(iOS 14.0, *)
final class UIActionButtonCaptureTests: XCTestCase {
    private var owner: MockUserpilot!
    private var button: UIButton!
    private var events: [Event] = []
    private var actionCount = 0

    override func setUp() {
        super.setUp()
        owner = MockUserpilot(config: Userpilot.Config(token: "ACTION-\(UUID().uuidString)")
            .defaultInstance(false).appFramework(.UIKit).enableInteractionAutoCapture())
        owner.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
        button = UIButton(type: .system)
        button.setTitle("Pay", for: .normal)
        button.accessibilityIdentifier = "pay_button"
        owner.attachToView(button)
        AutoCaptureSwizzler.swizzleControlUIAction()
        button.addAction(UIAction { [weak self] _ in self?.actionCount += 1 }, for: .touchUpInside)
    }

    override func tearDown() {
        button = nil
        owner = nil
        events = []
        actionCount = 0
        super.tearDown()
    }

    func testDirectAction_runsOnceAndCapturesControlMetadataWithoutInventingSelector() throws {
        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(actionCount, 1)
        XCTAssertEqual(events.count, 1)
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.targetClass] as? String, "UIButton")
        XCTAssertEqual(properties[Constants.AutoCapture.targetText] as? String, "Pay")
        XCTAssertEqual(properties[Constants.AutoCapture.accessibilityIdentifier] as? String, "pay_button")
        XCTAssertEqual(properties[Constants.AutoCapture.rawInteractionType] as? String, "tap")
        XCTAssertNil(properties[Constants.AutoCapture.targetAction])
        XCTAssertNil(properties[Constants.AutoCapture.ownerTargetClass])
    }

    func testPrimaryAction_usesTheSameCapturePath() {
        let action = UIAction(title: "Continue") { [weak self] _ in self?.actionCount += 1 }
        let primaryButton = UIButton(type: .system, primaryAction: action)
        owner.attachToView(primaryButton)

        primaryButton.sendActions(for: .primaryActionTriggered)

        XCTAssertEqual(actionCount, 1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.properties?[Constants.AutoCapture.targetText] as? String, "Continue")
    }

    func testInstallation_isIdempotent() {
        AutoCaptureSwizzler.swizzleControlUIAction()
        AutoCaptureSwizzler.swizzleControlUIAction()

        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(actionCount, 1)
        XCTAssertEqual(events.count, 1)
    }

    func testIgnoredButton_runsItsActionWithoutCapture() {
        button.userpilotIgnoreInteractions = true
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(actionCount, 1)
        XCTAssertTrue(events.isEmpty)
    }

    func testRedactedButton_keepsTheExistingPlaceholder() {
        button.userpilotRedactText = true
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(events.first?.properties?[Constants.AutoCapture.targetText] as? String, "****")
    }

    func testStoppedOwner_dropsCaptureAndResumeAllowsIt() {
        owner.stopAutoCapture()
        button.sendActions(for: .touchUpInside)
        XCTAssertTrue(events.isEmpty)

        owner.resumeAutoCapture()
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(actionCount, 2)
        XCTAssertEqual(events.count, 1)
    }

    func testDisabledOwner_dropsCapture() {
        owner.config.enableInteractionAutoCapture = false
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(actionCount, 1)
        XCTAssertTrue(events.isEmpty)
    }

    func testRemovedOwner_doesNotRerouteToDefault() {
        let fallback = MockUserpilot(config: Userpilot.Config(token: "DEFAULT-\(UUID().uuidString)")
            .enableInteractionAutoCapture())
        var fallbackEvents: [Event] = []
        fallback.analyticsPublisher.onPublish = { fallbackEvents.append($0) }
        UserpilotRuntime.shared.removeInstance(owner)

        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(actionCount, 1)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(fallbackEvents.isEmpty)
    }

    func testTwoUIActions_runBothHandlersButPublishOneEvent() {
        button.addAction(UIAction { [weak self] _ in self?.actionCount += 1 }, for: .touchUpInside)

        button.sendActions(for: .touchUpInside)
        drainMainQueue()

        XCTAssertEqual(actionCount, 2, "Every app handler must still execute")
        XCTAssertEqual(events.count, 1, "One tap publishes one event")
        XCTAssertEqual(socketRequestCount(), 1)
    }

    // Hostless XCTest has no UIApplication to dispatch selectors. `captureSelectorDispatch` is what the
    // UIApplication.sendAction hook calls for a control, so calling it within the same tap reproduces
    // UIKit's dispatch of a button that has both a selector target and a UIAction.

    func testMixedButton_selectorFirst_publishesOneEventWithSelectorMetadata() throws {
        button.addTarget(self, action: #selector(selectorAction), for: .touchUpInside)

        button.captureSelectorDispatch(action: #selector(selectorAction), target: self, event: nil, owner: owner)
        button.sendActions(for: .touchUpInside)
        drainMainQueue()

        XCTAssertEqual(events.count, 1)
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.targetAction] as? String, "selectorAction")
    }

    func testMixedButton_uiActionFirst_stillPublishesOnlyTheSelectorEvent() throws {
        button.addTarget(self, action: #selector(selectorAction), for: .touchUpInside)

        button.sendActions(for: .touchUpInside)
        button.captureSelectorDispatch(action: #selector(selectorAction), target: self, event: nil, owner: owner)
        drainMainQueue()

        XCTAssertEqual(events.count, 1, "The UIAction capture yields to the selector capture of the same tap")
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.targetAction] as? String, "selectorAction")
    }

    func testMixedButton_selectorHandlerRemovesItsTarget_stillPublishesOneEvent() throws {
        // A one-shot button: the selector handler removes its target before the UIAction runs.
        button.addTarget(self, action: #selector(selectorAction), for: .touchUpInside)

        button.captureSelectorDispatch(action: #selector(selectorAction), target: self, event: nil, owner: owner)
        button.removeTarget(self, action: nil, for: .allEvents)
        button.sendActions(for: .touchUpInside)
        drainMainQueue()

        XCTAssertEqual(events.count, 1)
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.targetAction] as? String, "selectorAction")
    }

    func testMixedButton_withoutSelectorDispatchThisTap_publishesTheUIActionEvent() throws {
        // The selector target listens to another control event, so this tap reaches only the UIAction.
        button.addTarget(self, action: #selector(selectorAction), for: .touchDown)

        button.sendActions(for: .touchUpInside)
        XCTAssertTrue(events.isEmpty, "A button with selector targets waits for the end of the tap")
        drainMainQueue()

        XCTAssertEqual(events.count, 1)
        XCTAssertNil(try XCTUnwrap(events.first?.properties)[Constants.AutoCapture.targetAction])
    }

    func testMixedButton_releasedByItsHandler_stillPublishesItsTap() {
        weak var released: UIButton?
        autoreleasepool {
            let closing = UIButton(type: .system)
            closing.setTitle("Close", for: .normal)
            owner.attachToView(closing)
            closing.addTarget(self, action: #selector(selectorAction), for: .touchDown)
            closing.addAction(UIAction { _ in }, for: .touchUpInside)
            closing.sendActions(for: .touchUpInside)
            released = closing
        }
        XCTAssertNil(released, "Precondition: nothing keeps the button alive after its handler")

        drainMainQueue()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.properties?[Constants.AutoCapture.targetText] as? String, "Close")
    }

    func testTwoSelectorDispatchesInOneTap_publishOneEvent() {
        button.captureSelectorDispatch(action: #selector(selectorAction), target: self, event: nil, owner: owner)
        button.captureSelectorDispatch(action: #selector(selectorAction), target: self, event: nil, owner: owner)

        XCTAssertEqual(events.count, 1)
    }

    func testSeparateTaps_eachPublishOneEvent() {
        button.sendActions(for: .touchUpInside)
        drainMainQueue()
        button.sendActions(for: .touchUpInside)
        drainMainQueue()

        XCTAssertEqual(actionCount, 2)
        XCTAssertEqual(events.count, 2, "A tap's claim ends with its main-queue turn")
    }

    func testForwarding_usesTheBoundOwnerAndOptedInDefault() {
        let fallback = MockUserpilot(config: Userpilot.Config(token: "FORWARD-\(UUID().uuidString)")
            .enableInteractionAutoCapture().allowReceiveEventsFromExternalSource(true))
        var forwarded: [Event] = []
        fallback.analyticsPublisher.onPublish = { forwarded.append($0) }

        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(forwarded.count, 1)
        XCTAssertEqual(events.first?.properties as NSDictionary?, forwarded.first?.properties as NSDictionary?)
    }

    @objc private func selectorAction() { actionCount += 1 }

    /// Runs main-queue work already enqueued by the tap, including the end-of-tap publish decision.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }

    private func socketRequestCount() -> Int {
        // Exercise the real publisher: an ACK releases its queue, so a duplicate cannot hide behind inFlight.
        owner.storage.userId = "test-user"
        owner.socketManager.isSocketOpened = true
        let publisher = AnalyticsPublisher(container: owner.container)
        var requests = 0
        owner.socketManager.onPublishRequest = { request in
            requests += 1
            request.completion?(Message(), true)
        }
        for var event in events {
            event.screen = [Constants.AutoCapture.screenName: "Checkout"]
            publisher.testPublish(event)
        }
        publisher.testSettle()
        return requests
    }
}
