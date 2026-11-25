//
//  FlowStepEventsTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies each Flow step outcome maps to exactly its step events, with the latch after the run ended.
//

import XCTest
@testable import Userpilot

final class FlowStepEventsTests: XCTestCase {

    private let flowId = 4242
    private lazy var segment = FlowSegment(flowId: flowId, stepsCount: 3, screen: "Checkout", run: FlowRun())
    private lazy var first = step(id: 11, position: 1)
    private lazy var middle = step(id: 12, position: 2)
    private lazy var last = step(id: 13, position: 3)

    func testShown_sendsOnlyTheStepSeenEvent() {
        let outcome = FlowStepEvents.shown(segment, first)

        assertWire(outcome, [("seen_mobile_content_step", ["mobile_content_id": flowId, "step_id": 11])])
        XCTAssertFalse(outcome.run.hasEnded)
        XCTAssertEqual(outcome.callbacks.first, .experienceState(.started))
    }

    func testAdvancedOnAMiddleStep_completesOnlyThatStep() {
        let outcome = FlowStepEvents.advanced(segment, middle)

        assertWire(outcome, [("completed_mobile_content_step", ["mobile_content_id": flowId, "step_id": 12])])
        XCTAssertFalse(outcome.run.hasEnded)
        XCTAssertEqual(outcome.run.endedStepIds, [12])
        XCTAssertEqual(outcome.callbacks, [.stepState(.completed, stepId: 12, position: 2, stepsCount: 3)])
    }

    func testAdvancedOnTheFlowsLastStep_endsTheRun_andFiresCompleted() {
        let outcome = FlowStepEvents.advanced(segment, last)

        assertWire(outcome, [("completed_mobile_content_step", ["mobile_content_id": flowId, "step_id": 13])])
        XCTAssertTrue(outcome.run.hasEnded)
        XCTAssertEqual(outcome.callbacks.last, .experienceState(.completed))
        XCTAssertFalse(outcome.opensDeepLink)
    }

    func testLinked_opensTheDeepLinkOnlyFromTheFlowsLastStep() {
        let onLast = FlowStepEvents.linked(segment, last)
        let onMiddle = FlowStepEvents.linked(segment, middle)

        XCTAssertTrue(onLast.opensDeepLink)
        XCTAssertEqual(names(onLast), names(FlowStepEvents.advanced(segment, last)))
        XCTAssertEqual(onLast.callbacks, FlowStepEvents.advanced(segment, last).callbacks)
        XCTAssertFalse(onMiddle.opensDeepLink)
        XCTAssertEqual(names(onMiddle), names(FlowStepEvents.advanced(segment, middle)))
    }

    func testClosed_sendsDismissedWithTheClosedStepsOwnState() {
        let expected: [(FlowDismissAction?, String?)] = [
            (.endFlow, nil),
            (.dismissFlowShowNextSession, "session"),
            (.dismissFlowNeverShowAgain, "never_show_again"),
            (nil, nil)
        ]

        for (action, state) in expected {
            let outcome = FlowStepEvents.closed(segment, step(id: 12, position: 2, dismissAction: action))

            var payload: [String: Any] = ["mobile_content_id": flowId, "step_id": 12]
            payload["state"] = state
            assertWire(outcome, [("dismissed_mobile_content", payload)])
            XCTAssertTrue(outcome.run.hasEnded)
            XCTAssertEqual(outcome.callbacks.last, .experienceState(.dismissed))
        }
    }

    func testFailed_sendsOnlyMobileContentError_withTheSegmentsScreen() {
        let outcome = FlowStepEvents.failed(segment, middle, issue: "not_found")

        assertWire(outcome, [("mobile_content_error", [
            "mobile_content_id": flowId, "step_id": 12, "issue": "not_found", "screen": "Checkout"
        ])])
        XCTAssertFalse(outcome.run.hasEnded)
        XCTAssertTrue(FlowStepEvents.failed(segment, last, issue: "not_visible").run.hasEnded)
        let endFlow = step(id: 11, position: 1, fallback: .endFlow)
        XCTAssertTrue(FlowStepEvents.failed(segment, endFlow, issue: "ambiguous").run.hasEnded)
    }

    func testAFailedStep_firesNoStepCallback_andCompletedOnlyWhenItEndsTheRun() {
        let endFlow = step(id: 11, position: 1, fallback: .endFlow)

        XCTAssertEqual(FlowStepEvents.failed(segment, middle, issue: "not_found").callbacks, [])
        XCTAssertEqual(
            FlowStepEvents.failed(segment, endFlow, issue: "not_found").callbacks, [.experienceState(.completed)]
        )
        XCTAssertEqual(
            FlowStepEvents.failed(segment, last, issue: "not_found").callbacks, [.experienceState(.completed)]
        )
    }

    func testOnlyTargetAlertsMapToAnIssue() {
        let reasons = [
            "not_found", "not_visible", "not_in_view", "overlapped", "ambiguous",
            "invalid_selector", "unsupported_selector_version", "layout_unavailable", "screen_mismatch", "target_lost"
        ]

        let issues = reasons.compactMap { reason in FlowContentErrorEvent.issue(for: reason).map { (reason, $0) } }

        XCTAssertEqual(issues.map(\.0), ["not_found", "not_visible", "not_in_view", "overlapped", "ambiguous"])
        XCTAssertEqual(issues.map(\.1), issues.map(\.0))
    }

    func testNothingIsProduced_afterTheRunEnded_orForAStepThatAlreadyEnded() {
        var ended = segment
        ended.run = FlowStepEvents.closed(segment, first).run
        var stepEnded = segment
        stepEnded.run = FlowStepEvents.advanced(segment, first).run

        let latched = [
            FlowStepEvents.shown(ended, middle),
            FlowStepEvents.advanced(ended, middle),
            FlowStepEvents.linked(ended, last),
            FlowStepEvents.closed(ended, middle),
            FlowStepEvents.failed(ended, middle, issue: "not_found"),
            FlowStepEvents.advanced(stepEnded, first),
            FlowStepEvents.closed(stepEnded, first)
        ]

        for outcome in latched {
            XCTAssertTrue(outcome.events.isEmpty)
            XCTAssertTrue(outcome.callbacks.isEmpty)
            XCTAssertFalse(outcome.opensDeepLink)
        }
        XCTAssertEqual(latched.last?.run, stepEnded.run)
    }

    func testAFlowNeverSendsFlowLevelSeenCompleteOrStepDismissedEvents() {
        var current = segment
        var all: [FlowStepOutcome] = []
        for step in [first, middle, last] {
            for report in [FlowStepEvents.shown, FlowStepEvents.advanced] {
                let outcome = report(current, step)
                current.run = outcome.run
                all.append(outcome)
            }
        }
        all.append(FlowStepEvents.closed(segment, middle))
        all.append(FlowStepEvents.failed(segment, middle, issue: "overlapped"))

        let sent = Set(all.flatMap(names))
        XCTAssertTrue(sent.isDisjoint(with: [
            "seen_mobile_content", "complete_mobile_content", "dismissed_mobile_content_step"
        ]))
        XCTAssertEqual(all.flatMap(\.callbacks).filter { $0 == .experienceState(.started) }.count, 1)
    }

    func testAnalyticsReadsAShownFlowStepAndEveryRunEnd_fromTheTypedEvents_payloadsUnchanged() {
        let endFlow = step(id: 11, position: 1, fallback: .endFlow)

        let shown = FlowStepEvents.shown(segment, first).events.first
        let completedMiddle = FlowStepEvents.advanced(segment, middle).events.first
        let completedLast = FlowStepEvents.advanced(segment, last).events.first
        let skippedMiddle = FlowStepEvents.failed(segment, middle, issue: "not_found").events.first
        let skippedLast = FlowStepEvents.failed(segment, last, issue: "not_found").events.first
        let endedByError = FlowStepEvents.failed(segment, endFlow, issue: "not_found").events.first

        XCTAssertTrue(isFlowRunSeen(shown))
        XCTAssertFalse(endsRun(completedMiddle))
        XCTAssertTrue(endsRun(completedLast))
        XCTAssertEqual((skippedMiddle as? FlowContentErrorEvent)?.endsRun, false)
        XCTAssertEqual((skippedLast as? FlowContentErrorEvent)?.endsRun, true)
        XCTAssertEqual((endedByError as? FlowContentErrorEvent)?.endsRun, true)
        XCTAssertEqual(shown.map { NSDictionary(dictionary: $0.eventPayload) },
                       ["mobile_content_id": flowId, "step_id": 11] as NSDictionary)
        XCTAssertEqual(completedLast.map { NSDictionary(dictionary: $0.eventPayload) },
                       ["mobile_content_id": flowId, "step_id": 13] as NSDictionary)
        XCTAssertFalse(isFlowRunSeen(FlowExperienceStepActionEvent.seen(flowId: flowId, stepId: 11)))
    }

    // MARK: - Helpers

    private func isFlowRunSeen(_ event: ExperienceEvent?) -> Bool {
        guard case let .seen(_, _, fromFlowRun)? = event as? FlowExperienceStepActionEvent else { return false }
        return fromFlowRun
    }

    private func endsRun(_ event: ExperienceEvent?) -> Bool {
        guard case let .completed(_, _, endsRun)? = event as? FlowExperienceStepActionEvent else { return false }
        return endsRun
    }

    private func names(_ outcome: FlowStepOutcome) -> [String] {
        outcome.events.map(\.eventName)
    }

    private func assertWire(
        _ outcome: FlowStepOutcome,
        _ expected: [(String, [String: Any])],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(names(outcome), expected.map(\.0), file: file, line: line)
        for (event, wire) in zip(outcome.events, expected) {
            XCTAssertEqual(NSDictionary(dictionary: event.eventPayload), NSDictionary(dictionary: wire.1),
                           file: file, line: line)
        }
    }

    private func step(
        id: Int,
        position: Int,
        dismissAction: FlowDismissAction? = nil,
        fallback: FlowFallback? = nil
    ) -> Step {
        Step(
            id: id, order: position, sections: [], buttonAction: nil, mobileTheme: nil, position: position,
            settings: FlowStepSettings(
                position: nil, advanceOn: nil, fallback: fallback, dismissAction: dismissAction, backdrop: nil
            )
        )
    }
}
