//
//  ExperiencesPublisherDebugFlowTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Checks debugger history through renderer admission, a walk resumed on a later screen and terminal outcomes.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {
    func testDebuggerFollowsStepsAcrossCheckpointsAndKeepsAReplaySeparate() throws {
        let store = userpilot.debugEventStore
        store.start()
        let firstScreen = flowWalkPayload(types: ["modal"], stepsCount: 2)
        receiveScreen(firstScreen)
        try presentScheduled()
        XCTAssertEqual(store.flowRuns.first?.steps[401]?.state, .pending)
        try reportFlowStep(FlowStepEvents.shown)
        XCTAssertEqual(store.flowRuns.first?.state, .started)
        removeRenderer(try reportFlowStep(FlowStepEvents.advanced))
        XCTAssertEqual(store.flowRuns.first?.state, .paused)

        publisher.updateScreen("Settings")
        settle()
        var secondScreen = flowWalkPayload(types: ["slideout"], stepsCount: 2)
        var content = try XCTUnwrap(secondScreen["mobile_contents"] as? [String: Any])
        var steps = try XCTUnwrap(content["steps"] as? [[String: Any]])
        steps[0]["position"] = 2
        steps[0]["id"] = 402
        content["steps"] = steps
        secondScreen["mobile_contents"] = content
        receiveScreen(secondScreen, screen: "Settings")
        try presentScheduled()
        try reportFlowStep(FlowStepEvents.shown)
        XCTAssertEqual(store.flowRuns.first?.state, .inProgress)
        removeRenderer(try reportFlowStep(FlowStepEvents.advanced))
        let run = try XCTUnwrap(store.flowRuns.first)
        XCTAssertEqual(store.flowRuns.count, 1)
        XCTAssertEqual(run.state, .completed)
        XCTAssertEqual(run.steps[401]?.shownOn, "Home")
        XCTAssertEqual(run.steps[402]?.shownOn, "Settings")
        XCTAssertEqual(run.steps[402]?.type, .slideout)
        XCTAssertEqual(run.steps[402]?.position, 2)
        XCTAssertEqual(run.steps[402]?.state, .completed)
        XCTAssertEqual(run.total, 2)

        receiveScreen(firstScreen, screen: "Settings")
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.closed))
        XCTAssertEqual(store.flowRuns.map(\.number), [2, 1])
        XCTAssertEqual(store.flowRuns.map(\.state), [.dismissed, .completed])
        XCTAssertEqual(store.flowRuns[0].steps[401]?.state, .dismissed)
    }

    func testDebuggerCanStartMidFlowAndReportsErrorWithoutInventingAnAppearance() throws {
        let store = userpilot.debugEventStore
        let tooltip = try presentTooltipSegment(
            TooltipFixture.flowPayload(types: ["tooltip", "slideout"]), unresolved: ["target_401"]
        )
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        XCTAssertTrue(store.flowRuns.isEmpty)
        store.start()
        alertTargetNotFound(tooltip)
        removeRenderer(renderer)
        let run = try XCTUnwrap(store.flowRuns.first)
        XCTAssertEqual(run.state, .inProgress)
        XCTAssertEqual(run.steps[401]?.state, .failed)
        XCTAssertNil(run.steps[401]?.shownOn)
        XCTAssertEqual(run.steps[401]?.type, .tooltip)
        XCTAssertEqual(run.steps[401]?.errors, [.init(issue: "not_found", screen: "Home")])
        XCTAssertEqual(run.steps[402]?.state, .pending)
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))
        XCTAssertEqual(store.flowRuns.first?.state, .completed)
        XCTAssertEqual(store.flowRuns.first?.steps[401]?.state, .failed)
    }

    func testPreviewCompletionIsVisibleWithoutSendingAnalytics() throws {
        let store = userpilot.debugEventStore
        store.start()
        let flow = try XCTUnwrap(flowWalkPayload(types: ["modal"]).toJSONString()?.toFlowContent()?.flowContent)
        let preview = PreviewExperience(flow: flow, survey: nil, contentType: "flow", theme: try makePreview().theme)
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in completion(.success(preview)) }
        publisher.triggerPreviewExperience("40", [])
        settle()
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))
        let run = try XCTUnwrap(store.flowRuns.first)
        XCTAssertTrue(run.isPreview)
        XCTAssertEqual(run.state, .completed)
        XCTAssertEqual(run.steps[401]?.state, .completed)
        XCTAssertTrue(run.section.rows[0].value.contains("Shown on Home"))
        XCTAssertTrue(publishedEvents.isEmpty)
    }

    func testDebuggerEnabledBetweenSegmentsDoesNotLabelAnEarlierOutcomeAsPending() throws {
        let store = userpilot.debugEventStore
        receiveScreen(flowWalkPayload(types: ["modal", "slideout"]))
        try presentScheduled()
        removeRenderer(try reportFlowStep(FlowStepEvents.shown, FlowStepEvents.advanced))
        store.start()
        try presentScheduled()
        try reportFlowStep(FlowStepEvents.shown)
        let run = try XCTUnwrap(store.flowRuns.first)
        XCTAssertEqual(run.state, .inProgress)
        XCTAssertEqual(run.steps[401]?.state, .notObserved)
        XCTAssertNil(run.steps[401]?.shownOn)
        XCTAssertEqual(run.steps[402]?.state, .shown)
    }
}
