//
//  TooltipFlowStepEventsTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies a tooltip Flow segment's step outcomes and host callbacks.
//

import XCTest
@testable import Userpilot

/// Records the host callbacks a Flow segment fires, in order.
private final class FlowDelegateSpy: UserpilotExperienceDelegate {
    enum Call: Equatable {
        case flow(UserpilotExperienceState)
        case step(stepId: Int, state: UserpilotExperienceState, step: Int?, totalSteps: Int?)
    }
    private(set) var calls: [Call] = []

    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?,
        experienceState: UserpilotExperienceState
    ) {
        calls.append(.flow(experienceState))
    }

    // Signature is fixed by `UserpilotExperienceDelegate`.
    // swiftlint:disable:next function_parameter_count
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    ) {
        calls.append(.step(
            stepId: stepId.intValue, state: stepState, step: step?.intValue, totalSteps: totalSteps?.intValue))
    }
}

final class TooltipFlowStepEventsTests: XCTestCase {

    private var harness: TooltipTestHarness!
    // `experienceDelegate` is weak, so the spy is retained here.
    private var delegate: FlowDelegateSpy!
    private var outcomes: [FlowStepOutcome] = []
    private var flowEvents: [ExperienceEvent] { outcomes.flatMap(\.events) }

    override func tearDown() {
        harness = nil
        delegate = nil
        outcomes = []
        super.tearDown()
    }

    func testAFlowStep_reportsShownAtItsReveal_evenAlone_andNeverTheFlowLevelSeen() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip"], stepsCount: 3))

        sut.onExperienceSeen()
        sut.onExperienceSeen()

        XCTAssertTrue(harness.events.isEmpty)
        XCTAssertEqual(steps(flowEvents), [Wire.seen(401)])
        XCTAssertTrue(sut.isCurrentStepShown)
        XCTAssertEqual(delegate.calls, [
            .flow(.started), .step(stepId: 401, state: .started, step: 1, totalSteps: 3)
        ])
    }

    func testTheNextFlowStep_isSeenWhenItIsRevealed_notAtTheTapThatMovedToIt() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], stepsCount: 4))
        sut.onExperienceSeen()

        sut.onTooltipStepChanged(1)
        let shownAtTap = sut.isCurrentStepShown
        sut.onStepRevealed()
        sut.onStepRevealed()

        XCTAssertFalse(shownAtTap)
        XCTAssertEqual(steps(flowEvents), [Wire.seen(401), Wire.completed(401), Wire.seen(402)])
        XCTAssertTrue(harness.events.isEmpty)
    }

    func testAFlowStepsProgressAndCallbacks_useItsPositionAmongStepsCount() throws {
        let sut = try startSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], stepsCount: 6, firstPosition: 3))
        let first = (sut.progressStepIndex, sut.progressStepsCount)

        sut.onExperienceSeen()
        sut.onTooltipStepChanged(1)

        XCTAssertEqual(first.0, 2)
        XCTAssertEqual(first.1, 6)
        XCTAssertEqual(sut.progressStepIndex, 3)
        // The Flow started at position 1, on an earlier screen.
        XCTAssertEqual(delegate.calls, [
            .step(stepId: 401, state: .started, step: 3, totalSteps: 6),
            .step(stepId: 401, state: .completed, step: 3, totalSteps: 6)
        ])
    }

    func testTheSegmentsLastStep_isTheFlowsLastOnlyAtPositionStepsCount() throws {
        let continues = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], stepsCount: 3))
        continues.onTooltipStepChanged(1)
        let ends = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"]))
        ends.onTooltipStepChanged(1)

        XCTAssertTrue(continues.isLastStepOfSegment)
        XCTAssertFalse(continues.isLastStepOfFlow)
        XCTAssertTrue(ends.isLastStepOfSegment)
        XCTAssertTrue(ends.isLastStepOfFlow)
    }

    func testALink_recordsItsDeepLinkOnlyFromTheFlowsLastStep() throws {
        var recorded: [String] = []
        let middle = try startSegment(TooltipFixture.flowPayload(types: ["tooltip"], stepsCount: 2))
        harness.userpilot.experiencesPublisher.onSetCompletionDeepLink = { recorded.append($0.absoluteString) }
        middle.onExperienceSeen()
        middle.onExperienceCompleted(deepLink: "app://middle", isLink: true)
        let middleOutcomes = outcomes

        let last = try startSegment(TooltipFixture.flowPayload(types: ["tooltip"], stepsCount: 2, firstPosition: 2))
        harness.userpilot.experiencesPublisher.onSetCompletionDeepLink = { recorded.append($0.absoluteString) }
        last.onExperienceSeen()
        last.onExperienceCompleted(deepLink: "app://last", isLink: true)

        XCTAssertEqual(recorded, ["app://last"])
        XCTAssertEqual((middleOutcomes + outcomes).map(\.opensDeepLink), [false, false, false, true])
        XCTAssertTrue(harness.events.isEmpty)
    }

    func testOnlyTheUsersClose_endsAFlowStep_andSDKDrivenClosesSendNothing() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(
            types: ["tooltip"], stepsCount: 2, dismissAction: "dismiss_flow_show_next_session"))
        sut.onExperienceSeen()
        outcomes.removeAll()

        [TooltipDismissReason.targetLost, .sdkReset].forEach { sut.onTooltipDismissed(reason: $0) }
        let afterSDKCloses = outcomes
        sut.onTooltipDismissed(reason: .closeButton)
        sut.onTooltipDismissed(reason: .closeButton)

        XCTAssertTrue(afterSDKCloses.isEmpty)
        XCTAssertEqual(flowEvents.map(\.eventName), ["dismissed_mobile_content"])
        XCTAssertEqual(flowEvents.first?.eventPayload["state"] as? String, "session")
        XCTAssertTrue(sut.isFlowRunEnded)
        XCTAssertTrue(harness.events.isEmpty)
    }

    /// The host app's `endExperience()` ends a seen step like the close button.
    func testEndExperience_endsAFlowStepLikeTheCloseButton_withTheStepsState() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(
            types: ["tooltip"], stepsCount: 2, dismissAction: "dismiss_flow_never_show_again"))
        sut.onExperienceSeen()
        outcomes.removeAll()

        sut.onTooltipDismissed(reason: .hostClose)
        sut.onTooltipDismissed(reason: .closeButton)

        XCTAssertEqual(flowEvents.map(\.eventName), ["dismissed_mobile_content"])
        XCTAssertEqual(flowEvents.first?.eventPayload["state"] as? String, "never_show_again")
        XCTAssertTrue(sut.isFlowRunEnded)
        XCTAssertTrue(harness.events.isEmpty)
    }

    func testAFlowTargetError_sendsItsIssueOnce_andAsksForTheFallback() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], stepsCount: 3))

        let unusableLayout = sut.onTargetNotFound(error: .layoutUnavailable, attemptCount: 1, elapsedMs: 10)
        let notFound = sut.onTargetNotFound(error: .notFound, attemptCount: 5, elapsedMs: 3_000)
        let repeated = sut.onTargetNotFound(error: .ambiguous(matchCount: 2), attemptCount: 5, elapsedMs: 3_000)

        XCTAssertEqual([unusableLayout, notFound, repeated], [false, true, false])
        XCTAssertEqual(flowEvents.map(\.eventName), ["mobile_content_error"])
        XCTAssertEqual(NSDictionary(dictionary: flowEvents.first?.eventPayload ?? [:]), NSDictionary(dictionary: [
            "mobile_content_id": 40, "step_id": 401, "issue": "not_found", "screen": "Home"
        ]))
        XCTAssertTrue(harness.events.isEmpty)
        XCTAssertFalse(sut.isFlowRunEnded)
    }

    func testSkipStep_pagesToTheNextStepWithoutEvents_andKeepsTheSkippedStepEnded() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"], stepsCount: 3))
        sut.onTargetNotFound(error: .notVisible(matchCount: 1), attemptCount: 5, elapsedMs: 3_000)
        outcomes.removeAll()

        sut.onTooltipStepSkipped()
        let afterSkip = outcomes
        sut.onStepRevealed()
        sut.onExperienceCompleted()
        sut.onTooltipStepSkipped()

        XCTAssertTrue(afterSkip.isEmpty)
        XCTAssertEqual(sut.currentStepIndex, 1)
        XCTAssertEqual(steps(flowEvents), [Wire.seen(402), Wire.completed(402)])
        XCTAssertEqual(outcomes.last?.run.endedStepIds, [401, 402])
    }

    func testEndFlowOnTheFirstOfFourSteps_endsTheRunWithFlowCompletedOnly() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(
            types: ["tooltip", "tooltip", "tooltip", "tooltip"], fallbacks: [401: "end_flow"]))

        let runsFallback = sut.onTargetNotFound(error: .notFound, attemptCount: 5, elapsedMs: 3_000)

        XCTAssertTrue(runsFallback)
        XCTAssertTrue(sut.isFlowRunEnded)
        XCTAssertEqual(flowEvents.map(\.eventName), ["mobile_content_error", "complete_mobile_content"])
        XCTAssertEqual(delegate.calls, [.flow(.completed)])
    }

    func testOnlyAFlowSegment_startsATooltip() throws {
        let flow = try XCTUnwrap(
            TooltipFixture.flowPayload(types: ["tooltip"]).toJSONString()?.toFlowContent()?.flowContent)
        harness = TooltipTestHarness(flow: TooltipFixture.flowContent(stepCount: 1))
        harness.userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let sut = harness.makeViewModel()
        var bound: Bool?
        sut.bindData = { bound = $0 }

        sut.onStart()
        sut.onExperienceSeen()

        XCTAssertEqual(bound, false)
        XCTAssertTrue(harness.outcomes.isEmpty)
        XCTAssertTrue(harness.events.isEmpty)
    }

    func testTheFlowsLastStep_completesOnce_andEndsTheRun() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip"]))
        sut.onExperienceSeen()
        sut.onTooltipStepChanged(1)
        sut.onStepRevealed()
        outcomes.removeAll()

        XCTAssertTrue(sut.isLastStepOfFlow)
        sut.onExperienceCompleted()
        sut.onExperienceCompleted()

        XCTAssertEqual(steps(flowEvents), [Wire.completed(402)])
        XCTAssertTrue(sut.isFlowRunEnded)
        XCTAssertTrue(harness.events.isEmpty)
    }

    func testTheStepSkippedTo_sendsItsOwnTargetError() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip", "tooltip", "tooltip"]))

        sut.onTargetNotFound(error: .notFound, attemptCount: 5, elapsedMs: 3_000)
        sut.onTooltipStepSkipped()
        let nextStepSends = sut.onTargetNotFound(error: .overlapped(matchCount: 1), attemptCount: 5, elapsedMs: 3_000)

        XCTAssertTrue(nextStepSends)
        XCTAssertEqual(flowEvents.map(\.eventName), ["mobile_content_error", "mobile_content_error"])
        XCTAssertEqual(flowEvents.map { $0.eventPayload["step_id"] as? Int }, [401, 402])
        XCTAssertEqual(flowEvents.map { $0.eventPayload["issue"] as? String }, ["not_found", "overlapped"])
    }

    /// Swift delegates cannot throw, so the order stands in for Android's throwing-listener case: the
    /// publisher has every outcome before the host hears about it.
    func testAFlowStepOutcome_reachesThePublisherBeforeTheHostDelegate() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(types: ["tooltip"]))
        var callbacksBeforeEachOutcome: [Int] = []
        harness.userpilot.experiencesPublisher.onPublishFlowStepOutcome = { [weak self] in
            callbacksBeforeEachOutcome.append(self?.delegate.calls.count ?? -1)
            self?.outcomes.append($0)
        }

        sut.onExperienceSeen()
        sut.onExperienceCompleted()

        XCTAssertEqual(callbacksBeforeEachOutcome, [0, 2])
        XCTAssertEqual(delegate.calls.count, 4)
        XCTAssertEqual(steps(flowEvents), [Wire.seen(401), Wire.completed(401)])
        XCTAssertTrue(sut.isFlowRunEnded)
    }

    func testEachFlowTooltipStep_dimsWithItsOwnSettingsBackdrop() throws {
        let sut = try startSegment(TooltipFixture.flowPayload(
            types: ["tooltip", "tooltip"],
            backdrops: [401: ["enabled": true, "color": "#112233", "opacity": 60], 402: ["enabled": false]]
        ))

        let first = sut.tooltipTheme
        sut.onTooltipStepChanged(1)
        let second = sut.tooltipTheme

        XCTAssertTrue(first.backdropEnabled)
        XCTAssertEqual(first.backdrop?.color, "#112233")
        XCTAssertEqual(first.backdropOpacity, 0.6, accuracy: 0.0001)
        XCTAssertFalse(second.backdropEnabled)
    }

    // MARK: - Helpers

    private enum Wire: Equatable {
        case seen(Int), completed(Int), other(String, Int?)
    }

    private func steps(_ events: [ExperienceEvent]) -> [Wire] {
        events.map { event in
            let stepId = event.eventPayload["step_id"] as? Int
            switch (event.eventName, stepId) {
            case let ("seen_mobile_content_step", id?): return .seen(id)
            case let ("completed_mobile_content_step", id?): return .completed(id)
            default: return .other(event.eventName, stepId)
            }
        }
    }

    /// One tooltip segment of `payload`, with a fresh run, as the publisher hands it over.
    private func startSegment(_ payload: [String: Any]) throws -> TooltipViewModel {
        let experience = try XCTUnwrap(TooltipFixture.flowSegment(payload))
        XCTAssertNotNil(experience.flowSegment())
        harness = TooltipTestHarness(flow: TooltipFixture.flowContent(stepCount: 1))
        harness.userpilot.experiencesPublisher.onGetActiveMobileContent = { experience }
        harness.userpilot.experiencesPublisher.onPublishFlowStepOutcome = { [weak self] in self?.outcomes.append($0) }
        delegate = FlowDelegateSpy()
        harness.userpilot.experienceDelegate = delegate
        outcomes.removeAll()
        let sut = harness.makeViewModel()
        sut.onStart()
        return sut
    }
}
