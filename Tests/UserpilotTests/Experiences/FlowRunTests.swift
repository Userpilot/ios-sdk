//
//  FlowRunTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the Flow's run, kept apart from any renderer: pure progress and the host callbacks each step
//  outcome fires.
//

import XCTest
@testable import Userpilot

final class FlowRunTests: XCTestCase {

    private let stepsCount = 3
    private lazy var first = step(id: 1, position: 1)
    private lazy var middle = step(id: 2, position: 2)
    private lazy var last = step(id: 3, position: 3)

    func testStarted_firesOnce_forTheStepAtPositionOne() {
        let (run, callbacks) = FlowRun().shown(first, stepsCount: stepsCount)

        XCTAssertEqual(callbacks, [
            .experienceState(.started), .stepState(.started, stepId: 1, position: 1, stepsCount: stepsCount)
        ])
        XCTAssertTrue(run.hasStarted)
        XCTAssertEqual(
            run.shown(first, stepsCount: stepsCount).callbacks,
            [.stepState(.started, stepId: 1, position: 1, stepsCount: stepsCount)]
        )
    }

    func testLaterStepShown_firesOnlyItsStepCallback_neverFlowStarted() {
        let (run, callbacks) = FlowRun().shown(middle, stepsCount: stepsCount)

        XCTAssertEqual(callbacks, [.stepState(.started, stepId: 2, position: 2, stepsCount: stepsCount)])
        XCTAssertFalse(run.hasStarted)
    }

    func testCompletingAMiddleStep_endsThatStepButNotTheRun_withNoFlowLevelCallback() {
        let (run, callbacks) = FlowRun().completed(middle, stepsCount: stepsCount)

        XCTAssertEqual(callbacks, [.stepState(.completed, stepId: 2, position: 2, stepsCount: stepsCount)])
        XCTAssertEqual(run.endedStepIds, [2])
        XCTAssertFalse(run.hasEnded)
    }

    func testCompleted_firesOnlyWhenTheStepAtPositionStepsCountCompletes() {
        let (run, callbacks) = FlowRun().completed(last, stepsCount: stepsCount)

        XCTAssertEqual(callbacks, [
            .stepState(.completed, stepId: 3, position: 3, stepsCount: stepsCount), .experienceState(.completed)
        ])
        XCTAssertTrue(run.hasEnded)
    }

    func testDismissal_endsTheRun_andFiresDismissedOnce() {
        let (run, callbacks) = FlowRun().dismissed(middle, stepsCount: stepsCount)

        XCTAssertEqual(callbacks, [
            .stepState(.dismissed, stepId: 2, position: 2, stepsCount: stepsCount), .experienceState(.dismissed)
        ])
        XCTAssertTrue(run.hasEnded)
        assertNoOutcome(run.dismissed(last, stepsCount: stepsCount), keeps: run)
    }

    func testNoOutcome_afterTheRunEnded_orForAStepThatAlreadyEnded() {
        let ended = FlowRun().dismissed(first, stepsCount: stepsCount).run
        let stepEnded = FlowRun().completed(first, stepsCount: stepsCount).run

        for (run, step) in [(ended, last), (stepEnded, first)] {
            XCTAssertFalse(run.acceptsOutcome(step))
            assertNoOutcome(run.shown(step, stepsCount: stepsCount), keeps: run)
            assertNoOutcome(run.completed(step, stepsCount: stepsCount), keeps: run)
            assertNoOutcome(run.dismissed(step, stepsCount: stepsCount), keeps: run)
            assertNoOutcome(run.errored(step, stepsCount: stepsCount), keeps: run)
        }
        XCTAssertTrue(stepEnded.acceptsOutcome(middle))
    }

    func testEndFlowAndASkippedLastStep_fireCompletedOnce() {
        let endFlow = step(id: 1, position: 1, fallback: .endFlow)
        let skippedLast = step(id: 3, position: 3, fallback: .skipStep)

        for step in [endFlow, skippedLast] {
            let (run, callbacks) = FlowRun().errored(step, stepsCount: stepsCount)

            XCTAssertEqual(callbacks, [.experienceState(.completed)])
            XCTAssertTrue(run.hasEnded)
            XCTAssertTrue(run.errored(step, stepsCount: stepsCount).callbacks.isEmpty)
        }
    }

    func testSkippedMiddleStep_endsOnlyThatStep() {
        let (run, callbacks) = FlowRun().errored(middle, stepsCount: stepsCount)

        XCTAssertTrue(callbacks.isEmpty)
        XCTAssertEqual(run, FlowRun(endedStepIds: [2]))
    }

    func testFirstStepSkippedByError_startsTheFlowAtTheFirstStepShownAfterIt_once() {
        let skipped = FlowRun().errored(step(id: 1, position: 1, fallback: .skipStep), stepsCount: stepsCount)
        XCTAssertTrue(skipped.callbacks.isEmpty)
        XCTAssertFalse(skipped.run.hasStarted)

        let (run, callbacks) = skipped.run.shown(middle, stepsCount: stepsCount)
        XCTAssertEqual(callbacks, [
            .experienceState(.started), .stepState(.started, stepId: 2, position: 2, stepsCount: stepsCount)
        ])
        XCTAssertTrue(run.hasStarted)
        XCTAssertEqual(
            run.completed(middle, stepsCount: stepsCount).run.shown(last, stepsCount: stepsCount).callbacks,
            [.stepState(.started, stepId: 3, position: 3, stepsCount: stepsCount)]
        )
    }

    func testARunResumedPastPositionOne_neverStarts_evenWhenALaterStepErrors() {
        let errored = FlowRun().errored(middle, stepsCount: stepsCount).run

        let (run, callbacks) = errored.shown(last, stepsCount: stepsCount)
        XCTAssertEqual(callbacks, [.stepState(.started, stepId: 3, position: 3, stepsCount: stepsCount)])
        XCTAssertFalse(run.hasStarted)
        XCTAssertFalse(run.hasSkippedFirstStep)
    }

    func testTooltipTooltipModal_firesStartedAtTheFirstStep_andCompletedAtTheModal_nothingBetween() {
        var run = FlowRun()
        let perStep = [first, middle, last].map { step -> [ExperienceCallback] in
            let shown = run.shown(step, stepsCount: stepsCount)
            let completed = shown.run.completed(step, stepsCount: stepsCount)
            run = completed.run
            return (shown.callbacks + completed.callbacks).filter {
                if case .experienceState = $0 { return true }
                return false
            }
        }

        XCTAssertEqual(perStep, [[.experienceState(.started)], [], [.experienceState(.completed)]])
    }

    func testIsLastStepOfFlow_comparesPositionWithStepsCount_notThePayloadSize() {
        XCTAssertTrue(FlowRun().isLastStepOfFlow(last, stepsCount: stepsCount))
        XCTAssertFalse(FlowRun().isLastStepOfFlow(middle, stepsCount: stepsCount))
        XCTAssertFalse(FlowRun().isLastStepOfFlow(step(id: 9, position: nil), stepsCount: stepsCount))
    }

    // MARK: - Helpers

    private func assertNoOutcome(
        _ outcome: (run: FlowRun, callbacks: [ExperienceCallback]),
        keeps run: FlowRun,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(outcome.run, run, file: file, line: line)
        XCTAssertTrue(outcome.callbacks.isEmpty, file: file, line: line)
    }

    private func step(id: Int, position: Int?, fallback: FlowFallback? = nil) -> Step {
        Step(
            id: id, order: id, sections: [], buttonAction: nil, mobileTheme: nil, position: position,
            settings: fallback.map {
                FlowStepSettings(position: nil, advanceOn: nil, fallback: $0, dismissAction: nil, backdrop: nil)
            }
        )
    }
}
