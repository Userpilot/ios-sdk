//
//  TooltipStepEventsTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

/// Records step-state callbacks so tests can assert on what the host saw.
private final class StepDelegateSpy: UserpilotExperienceDelegate {
    struct StepCall: Equatable {
        let stepId: Int
        let state: UserpilotExperienceState
        let step: Int?
        let totalSteps: Int?
    }
    private(set) var stepCalls: [StepCall] = []

    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?,
        experienceState: UserpilotExperienceState
    ) {}

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
        stepCalls.append(StepCall(
            stepId: stepId.intValue, state: stepState,
            step: step?.intValue, totalSteps: totalSteps?.intValue))
    }
}

final class TooltipStepEventsTests: XCTestCase {

    private var harness: TooltipTestHarness!
    // `experienceDelegate` is weak, so the spy is retained here.
    private var delegate: StepDelegateSpy!

    override func tearDown() {
        harness = nil
        delegate = nil
        super.tearDown()
    }

    private func makeViewModel(
        stepCount: Int,
        selectorOnEveryStep: Bool = true
    ) -> TooltipViewModel {
        harness = TooltipTestHarness(
            flow: TooltipFixture.flowContent(
                stepCount: stepCount, selectorOnEveryStep: selectorOnEveryStep))
        delegate = StepDelegateSpy()
        harness.userpilot.experienceDelegate = delegate
        let sut = harness.makeViewModel()
        sut.onStart()
        return sut
    }

    func testTargetError_isSentOncePerStep() {
        // A new recovery cycle for the same step (re-anchor, rotation) reports again
        // through the coordinator; only the first report per step may leave the device.
        let sut = makeViewModel(stepCount: 3)

        sut.onTargetNotFound(error: .notFound, attemptCount: 5, elapsedMs: 3_000)
        sut.onTargetNotFound(error: .notVisible(matchCount: 1), attemptCount: 5, elapsedMs: 3_000)
        sut.onTooltipStepChanged(1)
        sut.onTargetNotFound(error: .overlapped(matchCount: 1), attemptCount: 5, elapsedMs: 3_000)

        let reports = harness.flowEvents.filter { $0.eventName == SDKEventsName.flowContentError.rawValue }
        XCTAssertEqual(reports.map { $0.eventPayload["step_id"] as? Int }, [0, 1])
    }

    func testTargetingFollowsTheCurrentStep() {
        let sut = makeViewModel(stepCount: 3)

        // `ElementSelector` is not Equatable; the fixture gives each step a
        // distinct accessibility identifier.
        let first = sut.selector?.effectiveProperties["accessibility_identifier"]
        sut.onTooltipStepChanged(1)
        let second = sut.selector?.effectiveProperties["accessibility_identifier"]

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first, second)
    }

    func testReAnchoringSameStep_doesNotReEmitAnything() {
        // A re-anchor after scroll/rotation/parked retry re-renders the same
        // step; events fire on logical entry only.
        let sut = makeViewModel(stepCount: 3)
        sut.onExperienceSeen()
        sut.onTooltipStepChanged(1)
        sut.onStepRevealed()
        let eventsBefore = harness.flowEvents.map(\.eventName)
        let callsBefore = delegate.stepCalls

        sut.onTooltipStepChanged(1)
        sut.onStepRevealed()
        sut.onTooltipStepChanged(1)

        XCTAssertEqual(sut.currentStepIndex, 1)
        XCTAssertEqual(harness.flowEvents.map(\.eventName), eventsBefore)
        XCTAssertEqual(delegate.stepCalls, callsBefore)
    }

    func testReAnchoringAtIndexZero_emitsNoStepEvents() {
        let sut = makeViewModel(stepCount: 3)

        sut.onTooltipStepChanged(0)
        sut.onTooltipStepChanged(0)

        XCTAssertTrue(harness.flowEvents.isEmpty)
        XCTAssertTrue(delegate.stepCalls.isEmpty)
    }

    func testOutOfRangeIndex_isIgnored() {
        let sut = makeViewModel(stepCount: 3)

        sut.onTooltipStepChanged(99)
        sut.onTooltipStepChanged(-1)

        XCTAssertEqual(sut.currentStepIndex, 0)
        XCTAssertTrue(harness.flowEvents.isEmpty)
        XCTAssertTrue(harness.events.isEmpty)
        XCTAssertTrue(delegate.stepCalls.isEmpty)
    }

    func testStepStateReportsPositionAndStepsCount() {
        let sut = makeViewModel(stepCount: 3)

        sut.onExperienceSeen()
        sut.onTooltipStepChanged(1)
        sut.onStepRevealed()

        XCTAssertEqual(delegate.stepCalls, [
            .init(stepId: 0, state: .started, step: 1, totalSteps: 3),
            .init(stepId: 0, state: .completed, step: 1, totalSteps: 3),
            .init(stepId: 1, state: .started, step: 2, totalSteps: 3)
        ])
    }

    // MARK: Per-step theme

    private func themedViewModel(orders: [Int]? = nil, stepCount: Int) -> TooltipViewModel {
        harness = TooltipTestHarness(
            flow: TooltipFixture.flowContent(
                stepCount: stepCount,
                orders: orders,
                stepThemes: (0..<stepCount).map(TooltipFixture.markedTheme)))
        let sut = harness.makeViewModel()
        sut.onStart()
        return sut
    }

    func testTheme_followsEachStepOfTheTour() {
        let sut = themedViewModel(stepCount: 3)

        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-0")
        sut.onTooltipStepChanged(1)
        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-1")
        sut.onTooltipStepChanged(2)
        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-2")
    }

    func testTheme_followsTheStepShown_whenOrderDisagreesWithPayloadOrder() {
        // Paging order is [slot 1, slot 2, slot 0]. `mergedTheme[currentStepIndex]`
        // would show slot 0 first; identity mapping must show slot 1.
        let sut = themedViewModel(orders: [2, 0, 1], stepCount: 3)

        XCTAssertEqual(sut.currentTooltipStep?.id, 1)
        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-1")
        sut.onTooltipStepChanged(1)
        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-2")
        sut.onTooltipStepChanged(2)
        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-0")
    }

    func testTheme_duplicateStepIds_stillMapEachPageToItsOwnSlot() {
        // A malformed payload repeating `id` must not collapse onto one theme.
        let steps = (0..<3).map {
            TooltipFixture.step(id: 9, order: $0, mobileTheme: TooltipFixture.markedTheme($0))
        }
        var flow = TooltipFixture.flowContent(stepCount: 3)
        flow = FlowContent(
            id: flow.id, type: flow.type, steps: steps, mobileTheme: flow.mobileTheme,
            screens: [], screenType: .all, localeCode: "en")
        harness = TooltipTestHarness(flow: flow)
        let sut = harness.makeViewModel()
        sut.onStart()

        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-0")
        sut.onTooltipStepChanged(2)
        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-2")
    }

    func testTheme_singleStepResolvesItsOwnTheme() {
        let sut = themedViewModel(stepCount: 1)

        XCTAssertEqual(sut.tooltipTheme.colors?.backgroundColor, "slot-0")
    }
}
