//
//  ExperiencesPublisherHeldPushTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the held server push: one slot where the latest push wins, started where the fake reload
//  would go, and dropped by screen change, logout, preview, capture mode and a completion deep link. The
//  reload it replaced is still sent when it ends, unless its own reload, a deep link or a screen change
//  supersedes it.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {

    func testAServerPushDuringAnActiveExperience_startsAfterItEnds_withNoFakeReloadInBetween() throws {
        let first = try holdPushDuringExperience()
        XCTAssertTrue(userpilot.mockLogger.loggedInfos.contains("⏳ Server push held until the current experience ends"))

        closeNaturally(first)

        XCTAssertEqual(try presentNext(), 20)
        XCTAssertEqual(reloadCount, 0)
        closeNaturally(try XCTUnwrap(publisher.activeRendererID), flowId: 20)
        XCTAssertEqual(reloadCount, 1)
    }

    /// A non-null `request_id` answers a request, whatever its type; only a missing or null one is a push.
    func testAMessageCarryingARequestID_isAReply_andStartsNothing() {
        for requestID in ["req-1", 7] as [Any] {
            var response = MockContentFactory.makeFlowContentPayload()
            response["request_id"] = requestID
            publisher.onNewMessage(Message(payload: ["payload": response]))
            publisher.mockWaitForQueue()
        }

        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testAServerPushDuringAFlowWalk_startsWhenTheWalkEnds_insteadOfItsReload() throws {
        receiveScreen(flowWalkPayload(types: ["modal"]))
        try presentScheduled()
        publisher.onNewMessage(serverPush(flowId: 20))
        publisher.mockWaitForQueue()

        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))

        XCTAssertEqual(try presentNext(), 20)
        XCTAssertEqual(reloadCount, 0)
    }

    func testTheLatestHeldPush_wins() throws {
        let first = try holdPushDuringExperience(pushedId: 20)
        publisher.onNewMessage(serverPush(flowId: 30))
        publisher.mockWaitForQueue()

        closeNaturally(first)

        XCTAssertEqual(try presentNext(), 30)
    }

    func testAnEmptyOrInvalidPush_neverTakesTheSlot() throws {
        let first = try holdPushDuringExperience(pushedId: 20)
        publisher.onNewMessage(Message(payload: ["payload": ["request_id": NSNull()]]))
        publisher.onNewMessage(Message(payload: ["payload": ["request_id": NSNull(), "mobile_contents": ["id": "x"]]]))
        publisher.mockWaitForQueue()

        closeNaturally(first)

        XCTAssertEqual(try presentNext(), 20)
    }

    func testAManualTriggerWhileBusy_isStillDropped_andNeverHeld() throws {
        let first = try holdPushDuringExperience()
        publisher.triggerExperience("flow-b")
        publisher.mockWaitForQueue()

        closeNaturally(first)

        XCTAssertFalse(userpilot.analyticsPublisher.requests.contains { $0.event is FetchExperienceEvent })
        XCTAssertEqual(try presentNext(), 20)
    }

    func testAScreenChange_dropsTheHeldPush() throws {
        _ = try holdPushDuringExperience()

        publisher.updateScreen("Other")
        settle()

        assertNothingStarted()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testLogout_dropsTheHeldPush() throws {
        _ = try holdPushDuringExperience()

        publisher.logout()
        settle()

        assertNothingStarted()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testAPreview_dropsTheHeldPush() throws {
        _ = try holdPushDuringExperience()
        let preview = try makePreview()
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in completion(.success(preview)) }

        publisher.triggerPreviewExperience("preview-a", [])
        settle()
        // The preview's fetch reply returns to the queue one turn after the renderer's removal started it.
        publisher.mockWaitForQueue()
        try presentScheduled()
        let previewRenderer = try XCTUnwrap(publisher.activeRendererID)
        XCTAssertFalse(publisher.canRequestScreenEvent(), "The preview owns admission")
        publisher.experienceDidFinishDismissing(rendererID: previewRenderer)
        settle()

        assertNothingStarted()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testCaptureMode_dropsTheHeldPush() throws {
        _ = try holdPushDuringExperience()
        let owner = MockBuilderCaptureCoordinator()
        BuilderCaptureMode.begin(owner)
        defer { BuilderCaptureMode.end(owner) }

        publisher.endExperience(manualClose: true)
        settle()
        BuilderCaptureMode.end(owner)
        settle()

        assertNothingStarted()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testAPushArrivingDuringCaptureMode_isNeverHeld() throws {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let first = try XCTUnwrap(publisher.activeRendererID)
        let owner = MockBuilderCaptureCoordinator()
        BuilderCaptureMode.begin(owner)
        defer { BuilderCaptureMode.end(owner) }
        publisher.onNewMessage(serverPush(flowId: 20))
        publisher.mockWaitForQueue()
        BuilderCaptureMode.end(owner)

        closeNaturally(first)

        assertNothingStarted()
        XCTAssertEqual(reloadCount, 1)
    }

    func testACompletionDeepLink_dropsTheHeldPush() throws {
        let opened = expectation(description: "completion link opened")
        userpilot.linkOpener.onHandleURL = { url in
            XCTAssertEqual(url.absoluteString, "shop://carts")
            opened.fulfill()
        }
        let first = try holdPushDuringExperience()

        publisher.setCompletionDeepLink("shop://carts", rendererID: first)
        closeNaturally(first, hasDeepLink: true)

        wait(for: [opened], timeout: 2)
        assertNothingStarted()
        XCTAssertEqual(reloadCount, 0)
    }

    // MARK: - The reload a held push owes

    func testAHeldNPSThatReplacedAWalksReload_sendsThatReloadWhenItEnds() throws {
        receiveScreen(flowWalkPayload(types: ["modal"]))
        try presentScheduled()
        publisher.onNewMessage(npsPush())
        publisher.mockWaitForQueue()

        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))
        let beforeNPSEnds = reloadCount
        try presentScheduled()
        let nps = try XCTUnwrap(publisher.activeRendererID)
        publisher.publishInternalSDKEvent(NPSExperienceActionEvent.dismissed, rendererID: nps)
        publisher.mockWaitForQueue()
        removeRenderer(nps)

        XCTAssertEqual(beforeNPSEnds, 0)
        XCTAssertEqual(reloadCount, 1)
    }

    func testAHeldNPSSuppressedOnThisScreen_leavesTheWalksReloadToGoOutAtOnce() throws {
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        try presentScheduled()
        removeRenderer(try XCTUnwrap(publisher.activeRendererID))
        receiveScreen(flowWalkPayload(types: ["modal"]))
        try presentScheduled()
        publisher.onNewMessage(npsPush())
        publisher.mockWaitForQueue()

        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))

        XCTAssertEqual(reloadCount, 1)
        assertNothingStarted()
    }

    func testAHeldPushWithItsOwnReload_sendsOnlyThatOne() throws {
        let first = try holdPushDuringExperience()
        closeNaturally(first)

        XCTAssertEqual(try presentNext(), 20)
        XCTAssertEqual(reloadCount, 0)
        closeNaturally(try XCTUnwrap(publisher.activeRendererID), flowId: 20)

        XCTAssertEqual(reloadCount, 1)
    }

    func testAHeldPushRemovedWithoutAClose_stillSendsTheReloadItReplaced() throws {
        let first = try holdPushDuringExperience()
        closeNaturally(first)

        XCTAssertEqual(try presentNext(), 20)
        removeRenderer(try XCTUnwrap(publisher.activeRendererID))

        XCTAssertEqual(reloadCount, 1)
    }

    func testAHeldPushOpeningADeepLink_cancelsTheReloadItOwes() throws {
        let opened = expectation(description: "completion link opened")
        userpilot.linkOpener.onHandleURL = { _ in opened.fulfill() }
        let first = try holdPushDuringExperience()
        closeNaturally(first)
        XCTAssertEqual(try presentNext(), 20)
        let pushed = try XCTUnwrap(publisher.activeRendererID)

        publisher.setCompletionDeepLink("shop://carts", rendererID: pushed)
        closeNaturally(pushed, flowId: 20, hasDeepLink: true)

        wait(for: [opened], timeout: 2)
        XCTAssertEqual(reloadCount, 0)
    }

    func testAScreenChangeDuringAHeldPush_cancelsTheReloadItOwes() throws {
        let first = try holdPushDuringExperience()
        closeNaturally(first)
        XCTAssertEqual(try presentNext(), 20)

        publisher.updateScreen("Other")
        settle()

        XCTAssertEqual(reloadCount, 0)
        XCTAssertNil(publisher.activeRendererID)
    }

    // MARK: - Helpers

    /// Shows Flow 77, then sends a server push for Flow `pushedId` while it is visible.
    private func holdPushDuringExperience(pushedId: Int = 20) throws -> UUID {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        publisher.onNewMessage(serverPush(flowId: pushedId))
        publisher.mockWaitForQueue()
        XCTAssertEqual(publisher.activeRendererID, renderer)
        XCTAssertFalse(displayDelay.hasAction)
        return renderer
    }

    /// A server push (`request_id` null; a missing key means the same) carrying Flow `flowId`.
    private func serverPush(flowId: Int) -> Message {
        var response = MockContentFactory.makeFlowContentPayload()
        var content = response["mobile_contents"] as? [String: Any] ?? [:]
        content["id"] = flowId
        response["mobile_contents"] = content
        response["request_id"] = NSNull()
        return Message(payload: ["payload": response])
    }

    /// A server push carrying the NPS fixture.
    private func npsPush() -> Message {
        var response = MockContentFactory.makeNPSContentPayload()
        response["request_id"] = NSNull()
        return Message(payload: ["payload": response])
    }

    /// Sends the Flow's close event, then finishes the renderer's dismissal.
    private func closeNaturally(_ renderer: UUID, flowId: Int = 77, hasDeepLink: Bool = false) {
        publisher.publishInternalSDKEvent(
            FlowExperienceActionEvent.completed(flowId: flowId, hasDeepLink: hasDeepLink), rendererID: renderer
        )
        publisher.mockWaitForQueue()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
    }

    /// Presents the experience waiting on its display delay and returns its content id.
    private func presentNext() throws -> Int? {
        try presentScheduled()
        return publisher.activeExperience?.experienceId()
    }

    private func assertNothingStarted(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(publisher.activeRendererID, file: file, line: line)
        XCTAssertFalse(displayDelay.hasAction, file: file, line: line)
    }
}
