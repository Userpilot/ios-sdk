//
//  TooltipFlowPagingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the tooltip renderer's Flow mode: one overlay per segment, the target tap, fade-and-park,
//  the step fallbacks and the timing of each step's events.
//

import XCTest
@testable import Userpilot

final class TooltipFlowPagingTests: XCTestCase {

    private var harness: TooltipTestHarness!
    private var targeting: MockTooltipTargeting!
    private var host: UIViewController!
    private var outcomes: [FlowStepOutcome] = []
    private var timeline: [String] = []
    private var flowEvents: [ExperienceEvent] { outcomes.flatMap(\.events) }

    override func tearDown() {
        harness = nil
        targeting = nil
        host = nil
        outcomes = []
        timeline = []
        super.tearDown()
    }

    func testAFlowTargetTap_advancesInTheSameOverlay_thenCompletesTheSegmentsLastStep() throws {
        let sut = try present(types: ["tooltip", "tooltip"], stepsCount: 3, resolvable: ["target_401", "target_402"])

        sut.onTargetTapped()
        let afterFirstTap = sut.viewModel.currentStepIndex
        let wasHidden = sut.wrapperView.isHidden
        sut.onTargetTapped()

        XCTAssertEqual(afterFirstTap, 1)
        XCTAssertFalse(wasHidden)
        XCTAssertEqual(names(flowEvents), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401",
            "seen_mobile_content_step 402", "completed_mobile_content_step 402"
        ])
        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertEqual(removals, 1)
    }

    func testAFlowStepsEvents_fireAtTheTap_beforeTheOverlayFadesOut() throws {
        let sut = try present(types: ["tooltip"], resolvable: ["target_401"])
        var dismissedWhenReported: Bool?
        harness.userpilot.experiencesPublisher.onPublishFlowStepOutcome = { [weak self, weak sut] outcome in
            guard self?.names(outcome.events).contains("completed_mobile_content_step 401") == true else { return }
            dismissedWhenReported = sut?.hasCompletedDismissal
        }

        sut.onTargetTapped()

        XCTAssertEqual(dismissedWhenReported, false)
        XCTAssertTrue(sut.hasCompletedDismissal)
    }

    /// The segment pages by `order`, so position 3 — the Flow's last step — comes second.
    func testCompletingTheFlowsLastStepMidSegment_closesTheOverlay_withoutShowingTheRest() throws {
        let sut = try present(
            types: ["tooltip", "tooltip", "tooltip"], positions: [1, 3, 2],
            resolvable: ["target_401", "target_402", "target_403"])

        sut.onTargetTapped()
        sut.onTargetTapped()

        XCTAssertEqual(names(flowEvents), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401",
            "seen_mobile_content_step 402", "completed_mobile_content_step 402"
        ])
        XCTAssertEqual(outcomes.flatMap(\.callbacks).filter { $0 == .experienceState(.completed) }.count, 1)
        XCTAssertEqual(sut.viewModel.currentStepIndex, 1)
        XCTAssertTrue(sut.viewModel.isFlowRunEnded)
        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertEqual(removals, 1)
    }

    func testTheNextStepsTargetMissingAtFirst_parksTheOverlay_thenFadesItBackInWhenItResolves() throws {
        let sut = try present(
            types: ["tooltip", "tooltip"], stepsCount: 3, resolvable: ["target_401"], isAtEnd: false)

        sut.onTargetTapped()
        XCTAssertTrue(sut.isParked)
        XCTAssertEqual(sut.wrapperView.alpha, 0)
        let hidden = expectation(for: NSPredicate { _, _ in sut.wrapperView.isHidden }, evaluatedWith: nil)
        wait(for: [hidden], timeout: 2)

        targeting.resolvableIdentifiers.insert("target_402")
        sut.targetCoordinator.handleRotation()

        XCTAssertFalse(sut.isParked)
        XCTAssertFalse(sut.wrapperView.isHidden)
        XCTAssertEqual(sut.wrapperView.alpha, 1)
        XCTAssertEqual(names(flowEvents).last, "seen_mobile_content_step 402")
    }

    func testANextTargetThatResolvesAtOnce_isNeverParked() throws {
        let sut = try present(types: ["tooltip", "tooltip"], stepsCount: 3, resolvable: ["target_401", "target_402"])

        sut.onTargetTapped()

        XCTAssertFalse(sut.isParked)
        XCTAssertFalse(sut.hasPendingStep)
        XCTAssertEqual(sut.wrapperView.alpha, 1)
        XCTAssertFalse(sut.wrapperView.isHidden)
    }

    /// `viewWillTransition` hands a rotation to `handleRotation()`, which re-resolves the step showing.
    func testRotation_keepsTheFlowStepShowing_andItsRun() throws {
        let sut = try present(types: ["tooltip", "tooltip"], stepsCount: 3, resolvable: ["target_401", "target_402"])
        sut.onTargetTapped()

        sut.targetCoordinator.handleRotation()
        let stepAfterRotation = sut.viewModel.currentStepIndex
        let showingAfterRotation = !sut.wrapperView.isHidden && !sut.hasReachedTerminalState
        sut.onTargetTapped()

        XCTAssertEqual(stepAfterRotation, 1)
        XCTAssertTrue(showingAfterRotation)
        XCTAssertEqual(names(flowEvents), [
            "seen_mobile_content_step 401", "completed_mobile_content_step 401",
            "seen_mobile_content_step 402", "completed_mobile_content_step 402"
        ])
        XCTAssertEqual(outcomes.last?.run.endedStepIds, [401, 402])
    }

    func testTapsOnTheOutgoingCard_doNothingUntilTheNextStepIsSeen() throws {
        let sut = try present(
            types: ["tooltip", "tooltip"], stepsCount: 3, resolvable: ["target_401"], isAtEnd: false)
        sut.onTargetTapped()
        let reported = outcomes.count

        sut.handleAction(nil)
        sut.onTargetTapped()
        sut.wrapperView.cardView.onClose?()

        XCTAssertFalse(sut.hasReachedTerminalState)
        XCTAssertEqual(sut.viewModel.currentStepIndex, 1)
        XCTAssertEqual(outcomes.count, reported)
    }

    func testSkipStep_pagesPastAnUnresolvedStep_withoutClosingTheOverlay() throws {
        let sut = try present(
            types: ["tooltip", "tooltip"], stepsCount: 3, fallbacks: [401: "skip_step"], resolvable: ["target_402"])

        XCTAssertEqual(sut.viewModel.currentStepIndex, 1)
        XCTAssertFalse(sut.hasReachedTerminalState)
        XCTAssertFalse(sut.wrapperView.isHidden)
        XCTAssertEqual(names(flowEvents), ["mobile_content_error 401", "seen_mobile_content_step 402"])
        XCTAssertEqual(removals, 0)
    }

    func testEndFlow_closesTheOverlayAtOnce_andReportsOnlyTheError() throws {
        let sut = try present(
            types: ["tooltip", "tooltip", "tooltip", "tooltip"], fallbacks: [401: "end_flow"], resolvable: [])
        settleMain()

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertTrue(sut.viewModel.isFlowRunEnded)
        XCTAssertEqual(names(flowEvents), ["mobile_content_error 401"])
        XCTAssertEqual(removals, 1)
    }

    func testCloseButton_endsTheFlow_andABackdropTapDoesNothing() throws {
        let sut = try present(types: ["tooltip", "tooltip"], stepsCount: 3, resolvable: ["target_401"])

        sut.wrapperView.backdropView.handleTap(at: CGPoint(x: 1, y: 1))
        let afterBackdropTap = sut.hasReachedTerminalState
        let stepAfterBackdropTap = sut.viewModel.currentStepIndex
        sut.wrapperView.cardView.onClose?()

        XCTAssertFalse(afterBackdropTap)
        XCTAssertEqual(stepAfterBackdropTap, 0)
        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertEqual(names(flowEvents), ["seen_mobile_content_step 401", "dismissed_mobile_content 401"])
    }

    // MARK: - Helpers

    private var removals: Int { timeline.filter { $0 == "removed" }.count }

    private func names(_ events: [ExperienceEvent]) -> [String] {
        events.map { "\($0.eventName) \($0.eventPayload["step_id"] as? Int ?? -1)" }
    }

    /// Lets `abandonPresentation`'s deferred dismissal run.
    private func settleMain() {
        let settled = expectation(description: "main queue drained")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
    }

    /// Presents a tooltip segment of `TooltipFixture.flowPayload` and starts resolving its first target.
    /// Only targets in `resolvable` are found. A missing one alerts on its first attempt while the screen
    /// is `isAtEnd`, and otherwise waits for a scroll. Outside a window UIKit removes the overlay at once;
    /// in one, it runs the native fade first.
    private func present(
        types: [String],
        stepsCount: Int? = nil,
        positions: [Int]? = nil,
        fallbacks: [Int: String] = [:],
        resolvable: Set<String>,
        isAtEnd: Bool = true
    ) throws -> TooltipViewController {
        let experience = try XCTUnwrap(TooltipFixture.flowSegment(TooltipFixture.flowPayload(
            types: types, stepsCount: stepsCount, positions: positions, fallbacks: fallbacks)))
        harness = TooltipTestHarness(flow: TooltipFixture.flowContent(stepCount: 1))
        let publisher = harness.userpilot.experiencesPublisher
        publisher.onGetActiveMobileContent = { experience }
        publisher.onPublishFlowStepOutcome = { [weak self] outcome in
            self?.outcomes.append(outcome)
            self?.timeline += self?.names(outcome.events) ?? []
        }
        publisher.onExperienceDidFinishDismissing = { [weak self] in self?.timeline.append("removed") }
        targeting = MockTooltipTargeting(owner: harness.userpilot)
        targeting.resolvableIdentifiers = resolvable
        targeting.isAtEnd = isAtEnd
        harness.userpilot.container.registerLazy(ElementTargeting.self, initializer: { [targeting] in targeting! })

        let sut = TooltipViewController(viewModel: harness.makeViewModel())
        XCTAssertNotNil(sut.admitTargetHost())
        sut.loadViewIfNeeded()
        sut.advanceReentryWindow = 0
        sut.retryIntervals = []
        // Stillness re-reads run at once, so a found target reveals in the same call.
        sut.targetCoordinator.scheduleStillnessCheck = { _, work in work() }
        addTeardownBlock { sut.targetCoordinator.stop() }
        host = UIViewController()
        host.present(sut, animated: false)
        sut.targetCoordinator.start(retryIntervals: sut.retryIntervals)
        return sut
    }
}
