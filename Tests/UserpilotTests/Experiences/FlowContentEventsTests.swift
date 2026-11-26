//
//  FlowContentEventsTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies each standalone whole-content outcome maps to exactly its host callbacks and its Flow-level and
//  step-level events, in order.
//

import XCTest
@testable import Userpilot

final class FlowContentEventsTests: XCTestCase {

    private let flowID = 4242
    private lazy var first = step(id: 11)
    private lazy var second = step(id: 12)

    func testOpened_sendsFlowSeen_thenTheFirstStepSeen() {
        let report = FlowContentEvents.opened(content(first, second))

        XCTAssertEqual(report.callbacks, [
            .experienceState(.started), .stepState(.started, stepId: 11, position: 1, stepsCount: 2)
        ])
        assertWire(report.events, [
            ("seen_mobile_content", ["mobile_content_id": flowID]),
            ("seen_mobile_content_step", ["mobile_content_id": flowID, "step_id": 11])
        ])
        XCTAssertFalse(isFlowRunSeen(report.events.last))
    }

    func testPaged_completesThePreviousStep_thenSeesTheCurrentOne() {
        let report = FlowContentEvents.paged(content(first, second), page: 1)

        XCTAssertEqual(report.callbacks, [
            .stepState(.completed, stepId: 11, position: 1, stepsCount: 2),
            .stepState(.started, stepId: 12, position: 2, stepsCount: 2)
        ])
        assertWire(report.events, [
            ("completed_mobile_content_step", ["mobile_content_id": flowID, "step_id": 11]),
            ("seen_mobile_content_step", ["mobile_content_id": flowID, "step_id": 12])
        ])
        XCTAssertFalse(endsRun(report.events.first))
        XCTAssertFalse(isFlowRunSeen(report.events.last))
    }

    func testCompleted_completesTheLastStep_thenTheFlow() {
        let report = FlowContentEvents.completed(content(first, second))

        XCTAssertEqual(report.callbacks, [
            .stepState(.completed, stepId: 12, position: 2, stepsCount: 2), .experienceState(.completed)
        ])
        assertWire(report.events, [
            ("completed_mobile_content_step", ["mobile_content_id": flowID, "step_id": 12]),
            ("complete_mobile_content", ["mobile_content_id": flowID])
        ])
        XCTAssertFalse(endsRun(report.events.first))
        XCTAssertEqual(report.events.map(\.hasDeepLink), [false, false])
    }

    func testCompleted_hasDeepLinkFollowsTheLastStepsOwnButton_andStaysOffTheWire() {
        let linked = step(id: 12, buttonAction: ButtonAction(buttonAction: "link", deepLink: "shop://carts"))
        let emptyLink = step(id: 12, buttonAction: ButtonAction(buttonAction: "link", deepLink: ""))

        let report = FlowContentEvents.completed(content(first, linked))

        XCTAssertEqual(report.events.map(\.hasDeepLink), [false, true])
        assertWire(report.events, [
            ("completed_mobile_content_step", ["mobile_content_id": flowID, "step_id": 12]),
            ("complete_mobile_content", ["mobile_content_id": flowID])
        ])
        let withEmptyLink = FlowContentEvents.completed(content(first, emptyLink))
        XCTAssertEqual(withEmptyLink.events.map(\.hasDeepLink), [false, false])
    }

    func testDismissed_sendsOnlyFlowDismissed_onTheStep_withNoState() {
        let report = FlowContentEvents.dismissed(content(first, second), furthestPage: 1)

        XCTAssertEqual(report.callbacks, [
            .stepState(.dismissed, stepId: 12, position: 2, stepsCount: 2), .experienceState(.dismissed)
        ])
        assertWire(report.events, [("dismissed_mobile_content", ["mobile_content_id": flowID, "step_id": 12])])
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

    private func assertWire(
        _ events: [ExperienceEvent],
        _ expected: [(String, [String: Any])],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(events.map(\.eventName), expected.map(\.0), file: file, line: line)
        for (event, wire) in zip(events, expected) {
            XCTAssertEqual(NSDictionary(dictionary: event.eventPayload), NSDictionary(dictionary: wire.1),
                           file: file, line: line)
        }
    }

    private func step(id: Int, buttonAction: ButtonAction? = nil) -> Step {
        Step(id: id, order: id, sections: [], buttonAction: buttonAction, mobileTheme: nil)
    }

    private func content(_ steps: Step...) -> FlowContent {
        FlowContent(
            id: flowID, type: .carousel, steps: steps, mobileTheme: ContentMobileTheme(id: 1, themeData: nil),
            screens: [], screenType: .all, localeCode: "en"
        )
    }
}
