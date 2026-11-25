//
//  ExperiencesPublisherFlowWalkTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies screen-reply admission and the Flow walk: one operation, one renderer per segment.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {

    // MARK: - Screen reply admission

    func testScreenReplyIsIgnoredWhileANewerScreenEventIsQueued_forEveryContentType() {
        userpilot.analyticsPublisher.onHasQueuedScreenEvent = { _ in true }
        let replies = [
            MockContentFactory.makeFlowContentPayload(),
            flowWalkPayload(types: ["modal"]),
            MockContentFactory.makeTooltipFlowPayload(stepCount: 1),
            MockContentFactory.makeSurveyContentPayload(),
            MockContentFactory.makeNPSContentPayload()
        ]

        replies.forEach { receiveScreen($0) }

        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
        let ignored = userpilot.mockLogger.loggedInfos
            .filter { $0 == "Screen response ignored - a newer screen event is queued" }
        XCTAssertEqual(ignored.count, replies.count)
    }

    func testScreenReplyIsAccepted_whenNoNewerScreenEventIsQueued() {
        var answeredScreen: String?
        userpilot.analyticsPublisher.onHasQueuedScreenEvent = {
            answeredScreen = $0?[Constants.Analytics.screenTitleProperty] as? String
            return false
        }

        receiveScreen(MockContentFactory.makeFlowContentPayload(), screen: "Home")

        XCTAssertEqual(answeredScreen, "Home")
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testAReplyIsNotEvenDecoded_whileANewerScreenEventIsQueued() {
        var reply = flowWalkPayload(types: ["modal"])
        var content = reply["mobile_contents"] as? [String: Any] ?? [:]
        content["type"] = "popup"
        reply["mobile_contents"] = content
        userpilot.analyticsPublisher.onHasQueuedScreenEvent = { _ in true }
        receiveScreen(reply)
        let errorsWhileQueued = userpilot.mockLogger.loggedErrors

        userpilot.analyticsPublisher.onHasQueuedScreenEvent = { _ in false }
        receiveScreen(reply)

        XCTAssertEqual(errorsWhileQueued, [])
        XCTAssertFalse(userpilot.mockLogger.loggedErrors.isEmpty, "the same reply fails to decode once admitted")
    }

    func testReplyForAnEarlierScreenIsAccepted_whenNoScreenEventIsQueued() {
        publisher.updateScreen("Settings")
        publisher.mockWaitForQueue()

        receiveScreen(MockContentFactory.makeFlowContentPayload(), screen: "Home")

        XCTAssertTrue(displayDelay.hasAction)
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

    // MARK: - Flow walk

    func testFlowWalkShowsEachSegmentInOneOperation_thenReloadsOnce() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "slideout"]))
        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is CarouselExperienceViewController)
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))

        XCTAssertTrue(displayDelay.hasAction)
        XCTAssertFalse(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is SlideOutBottomSheetViewController)
        let segment = try XCTUnwrap(publisher.activeExperience?.flowSegment())
        XCTAssertEqual(segment.run.endedStepIds, [401])
        XCTAssertEqual(segment.stepsCount, 2)
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))

        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 1)
        XCTAssertEqual(publishedEvents.map(\.eventName), [
            "seen_mobile_content_step", "completed_mobile_content_step",
            "seen_mobile_content_step", "completed_mobile_content_step"
        ])
    }

    func testAFlowWithoutSteps_releasesAdmissionWithoutARenderer() throws {
        receiveScreen(flowWalkPayload(types: []))
        try displayDelay.fire()
        settle()

        XCTAssertNil(host.presentedExperience)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
        XCTAssertTrue(userpilot.mockLogger.renderedLines.contains("‼️ Flow 40 dropped - it has no steps"))
    }

    func testFlowSegmentReadsAsTheProjectedRendererContent() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "slideout"], stepsCount: 5))
        try presentScheduled()

        let experience = try XCTUnwrap(publisher.activeExperience)
        XCTAssertEqual(experience.asFlowContent()?.type, .carousel)
        XCTAssertEqual(experience.asFlowContent()?.steps.map(\.id), [401])
        XCTAssertEqual(experience.flowSegment(), FlowSegment(flowId: 40, stepsCount: 5, screen: "Home", run: FlowRun()))
    }

    func testClosingAFlowStepEndsTheWalk_andReloads() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.closed))

        // The close event's one-second screen cooldown still applies, so only the release is checked.
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertFalse(publisher.isExperienceVisible)
        XCTAssertNil(publisher.activeExperience)
        XCTAssertEqual(reloadCount, 1)
        XCTAssertEqual(publishedEvents.map(\.eventName), ["seen_mobile_content_step", "dismissed_mobile_content"])
    }

    func testFlowStepRemovedBeforeItEnded_pausesTheWalkWithoutReload() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown))

        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
    }

    func testAFlowSegmentWithNoPresentationHost_pausesTheWalkWithoutAReload() throws {
        publisher.topViewControllerProvider = { nil }
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))

        try displayDelay.fire()
        settle()

        XCTAssertTrue(userpilot.mockLogger.loggedInfos.contains("Experience not shown - no free presentation host"))
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
        XCTAssertTrue(publishedEvents.isEmpty)
    }

    func testLogoutMidWalk_closesTheStepSilently_withoutAReload() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        try reportFlowStep(FlowStepEvents.shown)

        publisher.logout()
        settle()

        XCTAssertNil(publisher.activeRendererID)
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
        XCTAssertEqual(publishedEvents.map(\.eventName), ["seen_mobile_content_step"])
    }

    func testAPreviewMidWalk_closesTheStepSilently_withoutAReload() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        try reportFlowStep(FlowStepEvents.shown)
        let preview = try makePreview()
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in completion(.success(preview)) }

        publisher.triggerPreviewExperience("preview-a", [])
        settle()
        publisher.mockWaitForQueue()

        XCTAssertEqual(reloadCount, 0)
        XCTAssertEqual(publishedEvents.map(\.eventName), ["seen_mobile_content_step"])
    }

    /// A paused walk is the server's to resend, so the same Flow id is not treated as already shown.
    func testTheSameFlowArrivingAgainAfterItsWalkPaused_isAcceptedAgain() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown))

        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()

        let segment = publisher.activeExperience?.flowSegment()
        XCTAssertEqual(segment?.flowId, 40)
        XCTAssertEqual(segment?.run, FlowRun())
    }

    func testScreenChangeDuringAFlowStep_endsTheWalkSilently() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        try reportFlowStep(FlowStepEvents.shown)

        publisher.updateScreen("Next")
        settle()

        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
        XCTAssertEqual(publishedEvents.map(\.eventName), ["seen_mobile_content_step"])
    }

    func testScreenChangeBetweenSegments_cancelsTheNextSegment() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "slideout"]))
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))
        XCTAssertTrue(displayDelay.hasAction)

        publisher.updateScreen("Next")
        settle()

        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertNil(host.presentedExperience as? SlideOutBottomSheetViewController)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
    }

    func testLinkOnTheFlowsLastStep_opensTheLinkInsteadOfReloading() throws {
        let opened = expectation(description: "completion link opened")
        userpilot.linkOpener.onHandleURL = { url in
            XCTAssertEqual(url.absoluteString, "shop://carts")
            opened.fulfill()
        }
        receiveScreen(flowWalkPayload(types: ["slideout"]))
        try presentScheduled()
        publisher.setCompletionDeepLink("shop://carts", rendererID: publisher.activeRendererID)

        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.linked))

        wait(for: [opened], timeout: 2)
        XCTAssertEqual(reloadCount, 0)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testOutcomeFromAnotherRenderer_isIgnored() throws {
        receiveScreen(flowWalkPayload(types: ["modal", "modal"]))
        try presentScheduled()
        let segment = try XCTUnwrap(publisher.activeExperience?.flowSegment())
        let step = try XCTUnwrap(publisher.activeExperience?.asFlowContent()?.steps.first)

        publisher.publishFlowStepOutcome(FlowStepEvents.closed(segment, step), rendererID: UUID())
        publisher.publishFlowStepOutcome(FlowStepEvents.closed(segment, step), rendererID: nil)
        publisher.mockWaitForQueue()

        XCTAssertTrue(publishedEvents.isEmpty)
        XCTAssertNotNil(publisher.activeRendererID)
    }

    func testEveryWalkedSegment_recordsTheFlowsOwnContentIdAsSeen() throws {
        var seen: [Int] = []
        userpilot.analyticsPublisher.onExperiencePublished = { type, id in
            XCTAssertEqual(type, .flow)
            seen.append(id)
        }
        receiveScreen(flowWalkPayload(types: ["modal", "slideout", "modal"]))

        for _ in 0..<3 {
            try presentScheduled()
            removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))
        }

        XCTAssertEqual(seen, [40, 40, 40])
        XCTAssertEqual(reloadCount, 1)
    }

    // MARK: - Helpers

    /// A Flow reply with one step per `types` entry (`modal` or `slideout`), ids from 401, built from the
    /// contract fixture's modal and `bottom` slideout steps.
    func flowWalkPayload(types: [String], stepsCount: Int? = nil) -> [String: Any] {
        var payload = MockContentFactory.makeFlowContractPayload()
        var content = payload["mobile_contents"] as? [String: Any] ?? [:]
        let templates = content["steps"] as? [[String: Any]] ?? []
        content["steps"] = types.enumerated().map { index, type -> [String: Any] in
            var step = templates[safe: type == "slideout" ? 2 : 1] ?? [:]
            step["id"] = 401 + index
            step["order"] = index
            step["position"] = index + 1
            step["button_action"] = ["button_action": "next"]
            return step
        }
        content["id"] = 40
        content["steps_count"] = stepsCount ?? types.count
        content["screen_type"] = "all"
        content["screens"] = [String]()
        payload["mobile_contents"] = content
        return payload
    }

    /// Reports `outcomes` for the shown segment's step the way its renderer does, carrying the run forward.
    @discardableResult
    func reportFlowStep(_ outcomes: ((FlowSegment, Step) -> FlowStepOutcome)...) throws -> UUID {
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        let experience = try XCTUnwrap(publisher.getActiveExperience(rendererID: renderer))
        var segment = try XCTUnwrap(experience.flowSegment())
        let step = try XCTUnwrap(experience.asFlowContent()?.steps.first)
        for report in outcomes {
            let outcome = report(segment, step)
            segment.run = outcome.run
            publisher.publishFlowStepOutcome(outcome, rendererID: renderer)
        }
        publisher.mockWaitForQueue()
        return renderer
    }

    /// Tells the publisher the renderer's dismissal finished, as UIKit's completion would, then settles.
    func removeRenderer(_ renderer: UUID) {
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
    }
}
