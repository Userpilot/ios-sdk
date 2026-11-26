//
//  ExperiencesPublisherTooltipFlowTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Walks Flows with tooltip segments through the real tooltip renderer and its ViewModel; only the
//  element finder, the presentation host and the modal's renderer are doubles, so the `skip_step` and
//  `end_flow` fallbacks run for real.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {

    func testTooltipTooltipModal_firesStartedAtTheFirstTooltip_andCompletedAtTheModal_nothingBetween() throws {
        let tooltip = try presentTooltipSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip", "modal"]))
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        tooltip.onTargetTapped()
        let rendererAfterFirstTap = publisher.activeRendererID
        tooltip.onTargetTapped()
        publisher.mockWaitForQueue()
        removeRenderer(renderer)

        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is CarouselExperienceViewController)
        let run = try XCTUnwrap(publisher.activeExperience?.flowSegment()?.run)
        var modalCallbacks: [ExperienceCallback] = []
        typealias Report = (FlowSegment, Step) -> FlowStepOutcome
        let recording: (@escaping Report) -> Report = { report in
            { segment, step in
                let outcome = report(segment, step)
                modalCallbacks += outcome.callbacks
                return outcome
            }
        }
        removeRenderer(try reportFlowStep(recording(FlowStepEvents.shown), recording(FlowStepEvents.advanced)))

        XCTAssertTrue(run.hasStarted)
        XCTAssertFalse(run.hasEnded)
        XCTAssertEqual(run.endedStepIds, [401, 402])
        XCTAssertEqual(modalCallbacks.filter(\.isExperienceState), [.experienceState(.completed)])
        XCTAssertEqual(rendererAfterFirstTap, renderer)
        XCTAssertEqual(stepEvents(), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401",
            "seen_mobile_content_step 402", "completed_mobile_content_step 402",
            "seen_mobile_content_step 403", "completed_mobile_content_step 403"
        ])
        XCTAssertEqual(reloadCount, 1)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testEndFlowOnStepOneOfFour_sendsErrorThenCompletion_andOneReload() throws {
        userpilot.debugEventStore.start()
        let tooltip = try presentTooltipSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "tooltip", "modal", "modal"], fallbacks: [401: "end_flow"]),
            unresolved: ["target_401"]
        )
        let renderer = try XCTUnwrap(publisher.activeRendererID)

        alertTargetNotFound(tooltip)
        removeRenderer(renderer)

        XCTAssertTrue(tooltip.viewModel.isFlowRunEnded)
        let run = try XCTUnwrap(userpilot.debugEventStore.flowRuns.first)
        XCTAssertEqual(run.state, .completed)
        XCTAssertEqual(run.steps[401]?.state, .failed)
        XCTAssertTrue(run.section.rows[0].value.contains("not_found on Home"))
        XCTAssertEqual(run.section.rows[1].value, "Not observed")
        XCTAssertEqual(publishedEvents.map(\.eventName), ["mobile_content_error", "complete_mobile_content"])
        XCTAssertEqual(publishedEvents.last?.eventPayload as? [String: Int], ["mobile_content_id": 40])
        XCTAssertEqual(NSDictionary(dictionary: publishedEvents.first?.eventPayload ?? [:]), NSDictionary(dictionary: [
            "mobile_content_id": 40, "step_id": 401, "issue": "not_found", "screen": "Home"
        ]))
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 1)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testSkipStepMidRun_pagesToTheNextTooltip_andTheWalkContinuesToTheModal() throws {
        let tooltip = try presentTooltipSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "tooltip", "modal"], fallbacks: [401: "skip_step"]),
            unresolved: ["target_401"]
        )

        let renderer = try XCTUnwrap(publisher.activeRendererID)

        alertTargetNotFound(tooltip)
        XCTAssertFalse(tooltip.hasReachedTerminalState)
        tooltip.onTargetTapped()
        publisher.mockWaitForQueue()
        removeRenderer(renderer)

        XCTAssertEqual(stepEvents(), [
            "mobile_content_error 401", "seen_mobile_content_step 402", "completed_mobile_content_step 402"
        ])
        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is CarouselExperienceViewController)
        XCTAssertEqual(publisher.activeExperience?.asFlowContent()?.steps.map(\.id), [403])
        XCTAssertEqual(reloadCount, 0)
    }

    func testSkipStepOnThePayloadsLastStep_closesTheOverlay_andSendsOneReload() throws {
        let tooltip = try presentTooltipSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], stepsCount: 5, fallbacks: [402: "skip_step"]),
            unresolved: ["target_402"]
        )
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        tooltip.onTargetTapped()

        alertTargetNotFound(tooltip)
        removeRenderer(renderer)

        XCTAssertEqual(stepEvents(), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401", "mobile_content_error 402"
        ])
        XCTAssertFalse(tooltip.viewModel.isFlowRunEnded)
        XCTAssertTrue(tooltip.hasReachedTerminalState)
        XCTAssertEqual(reloadCount, 1)
    }

    func testSkipStepOnTheFlowsLastStep_endsTheRun_andSendsOneReload() throws {
        let tooltip = try presentTooltipSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], fallbacks: [402: "skip_step"]),
            unresolved: ["target_402"]
        )
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        tooltip.onTargetTapped()

        alertTargetNotFound(tooltip)
        removeRenderer(renderer)

        XCTAssertEqual(stepEvents(), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401", "mobile_content_error 402"
        ])
        XCTAssertTrue(tooltip.viewModel.isFlowRunEnded)
        XCTAssertEqual(reloadCount, 1)
    }

    func testCompletingTheFlowsLastStepMidSegment_closesTheOverlay_andSendsOneReload() throws {
        let tooltip = try presentTooltipSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "tooltip", "tooltip"], positions: [1, 3, 2]))
        let renderer = try XCTUnwrap(publisher.activeRendererID)

        tooltip.onTargetTapped()
        tooltip.onTargetTapped()
        publisher.mockWaitForQueue()
        removeRenderer(renderer)

        XCTAssertEqual(stepEvents(), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401",
            "seen_mobile_content_step 402", "completed_mobile_content_step 402"
        ])
        XCTAssertTrue(tooltip.hasReachedTerminalState)
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 1)
    }

    func testATooltipStep_isStillShowingAfterTheAppGoesToTheBackgroundAndComesBack() throws {
        let tooltip = try presentTooltipSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"]))
        let renderer = try XCTUnwrap(publisher.activeRendererID)

        [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification,
         UIApplication.willEnterForegroundNotification, UIApplication.didBecomeActiveNotification,
         UIScene.didActivateNotification]
            .forEach { lifecycleCenter.post(name: $0, object: nil) }
        // On return the host reports its screen again, and the reconnected socket can answer with content.
        publisher.updateScreen("Home")
        receiveScreen(TooltipFixture.flowPayload(types: ["modal"]))
        settle()

        XCTAssertEqual(publisher.activeRendererID, renderer)
        XCTAssertTrue(host.presentedExperience === tooltip)
        XCTAssertFalse(tooltip.hasReachedTerminalState)
        XCTAssertFalse(tooltip.wrapperView.isHidden)
        XCTAssertEqual(stepEvents(), ["seen_mobile_content_step 401"])
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
    }

    func testScreenChangeDuringATooltipStep_closesItSilently() throws {
        try presentTooltipSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"]))

        publisher.updateScreen("Next")
        settle()

        XCTAssertEqual(stepEvents(), ["seen_mobile_content_step 401"])
        XCTAssertEqual(reloadCount, 0)
    }

    // MARK: - Helpers

    /// Receives `payload` on `Home` and presents its tooltip segment with every target found except
    /// `unresolved`, whose first attempt fails. The first target is resolved and reported before returning.
    @discardableResult
    func presentTooltipSegment(_ payload: [String: Any], unresolved: Set<String> = []) throws -> TooltipViewController {
        let targeting = MockTooltipTargeting(owner: userpilot)
        targeting.resolvableIdentifiers = Set((401...409).map { "target_\($0)" }).subtracting(unresolved)
        userpilot.container.register(ElementTargeting.self, value: targeting)
        receiveScreen(payload)
        try presentScheduled()
        let tooltip = try XCTUnwrap(host.presentedExperience as? TooltipViewController)
        tooltip.loadViewIfNeeded()
        tooltip.advanceReentryWindow = 0
        // Stillness re-reads run at once, so a found target reveals in the same call.
        tooltip.targetCoordinator.scheduleStillnessCheck = { _, work in work() }
        tooltip.viewDidAppear(false)
        addTeardownBlock { tooltip.targetCoordinator.stop() }
        publisher.mockWaitForQueue()
        return tooltip
    }

    /// The step's retry ladder is spent at the screen's end, as the coordinator reports it.
    func alertTargetNotFound(_ tooltip: TooltipViewController) {
        tooltip.targetCoordinator.onTargetNotFound?(.notFound, 5, 3_000)
        publisher.mockWaitForQueue()
    }

    func stepEvents() -> [String] {
        publishedEvents.map { "\($0.eventName) \($0.eventPayload["step_id"] as? Int ?? -1)" }
    }
}

private extension ExperienceCallback {
    var isExperienceState: Bool {
        if case .experienceState = self { return true }
        return false
    }
}
