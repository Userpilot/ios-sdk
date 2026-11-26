//
//  ExperiencesPublisherEndExperienceTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The host app's `endExperience()` ends the visible Flow step whatever its type: `dismissed_mobile_content`
//  with the step's state, the run ends and one fake reload follows. A tooltip step that was never
//  revealed closes silently. Builder capture closes silently, like navigation.
//
//  The runner cannot finish a UIKit transition, so the chain is checked in two halves: a natively
//  presented renderer receives the close and reports it, and a report that arrives while the publisher
//  is closing ends the run once the renderer is removed.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {

    // MARK: - The renderer reports the close

    func testEndExperience_reachesAModalStep_whichReportsItsDismissal() throws {
        presentNatively()
        receiveScreen(walk(["modal", "modal"]))
        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is CarouselExperienceViewController)

        publisher.endExperience(manualClose: true)

        try assertTheRendererReportedTheDismissal()
    }

    func testEndExperience_reachesASlideOutStep_whichReportsItsDismissal() throws {
        presentNatively()
        receiveScreen(walk(["slideout", "modal"]))
        try presentScheduled()
        let renderer = host.presentedExperience
        XCTAssertTrue(renderer is SlideOutBottomSheetViewController || renderer is SlideOutDialogViewController)

        publisher.endExperience(manualClose: true)

        try assertTheRendererReportedTheDismissal()
    }

    func testEndExperience_reachesARevealedTooltipStep_whichReportsItsDismissal() throws {
        presentNatively()
        try presentTooltipSegment(walk(["tooltip", "modal"]))
        XCTAssertEqual(stepEvents(), ["seen_mobile_content_step 401"])

        publisher.endExperience(manualClose: true)

        try assertTheRendererReportedTheDismissal(after: ["seen_mobile_content_step 401"])
    }

    func testEndExperience_reachesATooltipStepNeverRevealed_whichClosesSilently() throws {
        presentNatively()
        let tooltip = try presentTooltipSegment(walk(["tooltip", "modal"]), unresolved: ["target_401"])

        publisher.endExperience(manualClose: true)
        let closing = expectation(for: NSPredicate { _, _ in tooltip.hasReachedTerminalState }, evaluatedWith: nil)
        wait(for: [closing], timeout: 2)
        settle()

        XCTAssertEqual(stepEvents(), [])
        XCTAssertFalse(displayDelay.hasAction)
    }

    // MARK: - The publisher ends the run

    func testAStepDismissedWhileEndExperienceCloses_endsTheRun_andReloadsOnce() throws {
        receiveScreen(walk(["slideout", "modal"]))
        try presentScheduled()
        let reportDismissal = try showTheStep()

        publisher.endExperience(manualClose: true)
        reportDismissal()
        settle()

        XCTAssertEqual(stepEvents(), ["seen_mobile_content_step 401", "dismissed_mobile_content 401"])
        XCTAssertFalse(displayDelay.hasAction, "the walk must not continue")
        XCTAssertEqual(reloadCount, 1)
        XCTAssertNil(publisher.activeRendererID)
    }

    /// A capture tap closes the visible experience silently and photographs the screen only once the
    /// step's renderer is gone (`BuilderCaptureCoordinator.captureOnMain`).
    func testBuilderCaptureClose_pausesTheRunSilently_andRunsTheCaptureAfterRemoval() throws {
        receiveScreen(walk(["modal", "modal"]))
        try presentScheduled()
        _ = try showTheStep()
        var stateWhenCaptureRuns: (events: [String], idle: Bool)?
        let captureRuns = expectation(description: "capture runs after removal")

        publisher.closeSilently { [weak self] in
            stateWhenCaptureRuns = (self?.stepEvents() ?? [], self?.publisher.activeRendererID == nil)
            captureRuns.fulfill()
        }
        wait(for: [captureRuns], timeout: 2)
        settle()

        XCTAssertEqual(stateWhenCaptureRuns?.events, ["seen_mobile_content_step 401"])
        XCTAssertEqual(stateWhenCaptureRuns?.idle, true)
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
    }

    func testAStepEndExperienceClosesSilently_pausesTheRun_withoutAReload() throws {
        receiveScreen(walk(["slideout", "modal"]))
        try presentScheduled()
        _ = try showTheStep()

        publisher.endExperience(manualClose: true)
        settle()

        XCTAssertEqual(stepEvents(), ["seen_mobile_content_step 401"])
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    // MARK: - Helpers

    /// Presents renderers through UIKit until teardown, so the publisher's close reaches them.
    private func presentNatively() {
        host.presentsNatively = true
        addTeardownBlock { [host] in host?.presentsNatively = false }
    }

    /// Flow 40 on `Home`, one step per type from 401; each step's close is `state: "session"`.
    private func walk(_ types: [String]) -> [String: Any] {
        TooltipFixture.flowPayload(types: types, dismissAction: "dismiss_flow_show_next_session")
    }

    /// Reports the visible step as shown and returns its dismissal as the renderer reports it from
    /// `triggerCloseExperience(manualClose: true)`: after the publisher started closing, before main
    /// removes the renderer.
    private func showTheStep() throws -> () -> Void {
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        let experience = try XCTUnwrap(publisher.getActiveExperience(rendererID: renderer))
        var segment = try XCTUnwrap(experience.flowSegment())
        let step = try XCTUnwrap(experience.asFlowContent()?.steps.first)
        let shown = FlowStepEvents.shown(segment, step)
        segment.run = shown.run
        publisher.publishFlowStepOutcome(shown, rendererID: renderer)
        publisher.mockWaitForQueue()
        return { [weak self] in
            self?.publisher.mockWaitForQueue()
            self?.publisher.publishFlowStepOutcome(FlowStepEvents.closed(segment, step), rendererID: renderer)
        }
    }

    /// The renderer reported step 401 of Flow 40 as `dismissed_mobile_content` with its state, and the walk
    /// does not go on to step 402.
    private func assertTheRendererReportedTheDismissal(
        after earlier: [String] = [], file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let reported = expectation(for: NSPredicate { [weak self] _, _ in
            self?.stepEvents().contains("dismissed_mobile_content 401") == true
        }, evaluatedWith: nil)
        wait(for: [reported], timeout: 2)
        settle()
        XCTAssertEqual(stepEvents(), earlier + ["dismissed_mobile_content 401"], file: file, line: line)
        XCTAssertEqual(publishedEvents.last?.eventPayload["state"] as? String, "session", file: file, line: line)
        XCTAssertFalse(displayDelay.hasAction, "the walk must not continue", file: file, line: line)
    }
}
