//
//  TooltipPagingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

/// Finishes a dismissal at once, standing in for the UIKit transition the runner never completes.
private final class ImmediateDismissHost: UIViewController {
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        completion?()
    }
}

final class TooltipPagingTests: XCTestCase {

    var harness: TooltipTestHarness!
    var targeting: MockTooltipTargeting!
    private var host: UIViewController?

    override func tearDown() {
        harness = nil
        targeting = nil
        host = nil
        super.tearDown()
    }

    func testExternalCloseDuringDeferredAbandonWaitsForRemoval() {
        let sut = makeController(stepCount: 1)
        present(sut)
        var dismissalCount = 0
        harness.userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { dismissalCount += 1 }
        let closed = expectation(description: "External close joins native removal")
        var externalCloseFinished = false

        sut.abandonPresentation()
        sut.triggerCloseExperience(manualClose: true) {
            externalCloseFinished = true
            closed.fulfill()
        }

        XCTAssertFalse(externalCloseFinished)
        XCTAssertEqual(dismissalCount, 0)
        wait(for: [closed], timeout: 1)
        XCTAssertEqual(dismissalCount, 1)
    }

    func testActionOnIntermediateStep_advancesWithoutCompleting() {
        let sut = makeRevealedController(stepCount: 3)

        sut.handleAction(nil)

        XCTAssertEqual(sut.viewModel.currentStepIndex, 1)
        XCTAssertFalse(sut.hasReachedTerminalState)
        XCTAssertFalse(sut.viewModel.isFlowRunEnded)
    }

    func testActionOnFinalStep_completes() {
        let sut = makeRevealedController(stepCount: 2)

        sut.handleAction(nil)   // 0 -> 1
        sut.handleAction(nil)   // 1 is final: complete

        XCTAssertEqual(sut.viewModel.currentStepIndex, 1)
        XCTAssertTrue(sut.hasReachedTerminalState)
    }

    func testSingleStepTooltip_actionCompletesImmediately() {
        let sut = makeRevealedController(stepCount: 1)

        sut.handleAction(nil)

        XCTAssertEqual(sut.viewModel.currentStepIndex, 0)
        XCTAssertTrue(sut.hasReachedTerminalState)
    }

    func testDoubleTap_advancesExactlyOneStep() {
        let sut = makeRevealedController(stepCount: 3, reentryWindow: 0.3)

        sut.handleAction(nil)
        sut.handleAction(nil)   // back-to-back: the user has not read step 1

        XCTAssertEqual(sut.viewModel.currentStepIndex, 1)
        XCTAssertEqual(stepEvents, ["seen_mobile_content_step 0", "completed_mobile_content_step 0",
                                    "seen_mobile_content_step 1"])
    }

    func testDeliberateLaterTap_stillAdvances() {
        // Guards the guard: it must not be satisfiable by breaking advancement.
        let sut = makeRevealedController(stepCount: 3, reentryWindow: 0.05)

        sut.handleAction(nil)
        let elapsed = expectation(description: "window elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { elapsed.fulfill() }
        wait(for: [elapsed], timeout: 1)
        sut.handleAction(nil)

        XCTAssertEqual(sut.viewModel.currentStepIndex, 2)
    }

    func testAdvanceBeyondLastStep_isRefused() {
        let sut = makeController(stepCount: 2)

        sut.advance(to: 9)

        XCTAssertEqual(sut.viewModel.currentStepIndex, 0)
    }

    func testAdvanceBackwards_isRefused() {
        let sut = makeRevealedController(stepCount: 3)
        sut.advance(to: 2)

        sut.advance(to: 1)

        XCTAssertEqual(sut.viewModel.currentStepIndex, 2)
    }

    func testAdvance_retargetsTheCoordinatorToTheNextStep() {
        let sut = makeRevealedController(stepCount: 3)
        XCTAssertEqual(targeting.resolvedIdentifiers.last, "tooltip-target-0")

        sut.handleAction(nil)

        // The coordinator itself, not the view model, asked about step 1's target.
        XCTAssertEqual(targeting.resolvedIdentifiers.last, "tooltip-target-1")
        XCTAssertEqual(sut.targetCoordinator.attemptCount, 1)   // reset, then one attempt
    }

    func testStepWithoutButtonLine_remainsClosable() {
        let sut = makeRevealedController(stepCount: 2, hasButtonLine: false)

        // The card's own close callback, as wired by `bindCard`.
        XCTAssertNotNil(sut.wrapperView.cardView.onClose)
        sut.wrapperView.cardView.onClose?()

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertEqual(harness.flowEvents.filter {
                $0.eventName == SDKEventsName.flowExperienceDismissed.rawValue
            }.count, 1)
    }

    func testDeepLink_notFollowedFromAnIntermediateStep() {
        // Even a link action only advances an intermediate step, so a leaking tap would navigate.
        let sut = makeRevealedController(stepCount: 3, deepLinkOnStep: 2)
        var followed: [URL] = []
        harness.userpilot.experiencesPublisher.onSetCompletionDeepLink = { followed.append($0) }

        sut.handleAction(ButtonAction(buttonAction: "link", deepLink: TooltipFixture.deepLink))
        sut.handleAction(ButtonAction(buttonAction: "link", deepLink: TooltipFixture.deepLink))

        XCTAssertEqual(sut.viewModel.currentStepIndex, 2)
        XCTAssertFalse(sut.hasReachedTerminalState)
        XCTAssertTrue(followed.isEmpty)
    }

    func testCompletionLink_recordedFromTheFinalStep() {
        // Positive control for the test above.
        let sut = makeRevealedController(stepCount: 2, deepLinkOnStep: 1)
        var followed: [URL] = []
        harness.userpilot.experiencesPublisher.onSetCompletionDeepLink = { followed.append($0) }

        sut.handleAction(nil)
        sut.handleAction(ButtonAction(buttonAction: "link", deepLink: TooltipFixture.deepLink))

        XCTAssertEqual(followed.map(\.absoluteString), [TooltipFixture.deepLink])
    }

    func testUnresolvableStepMidSegment_closesTheOverlayWithoutADismissal() {
        let sut = makeRevealedController(stepCount: 3)
        targeting.isUnrecoverable = true

        sut.handleAction(nil)           // advance -> step 1 cannot resolve

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertFalse(harness.flowEvents.contains {
            $0.eventName == SDKEventsName.flowExperienceDismissed.rawValue
        })
        XCTAssertFalse(sut.viewModel.isFlowRunEnded)
    }

    func testUnresolvableFirstStepNeverRevealed_emitsNoTerminalEvent() {
        let sut = makeController(stepCount: 1)
        targeting.isUnrecoverable = true
        let dismissed = expectation(description: "Renderer acknowledges UI removal")
        harness.userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { dismissed.fulfill() }

        present(sut)
        // The first attempt fails unrecoverably.
        sut.targetCoordinator.start(retryIntervals: sut.retryIntervals)
        // `abandonPresentation` hops one main-queue turn before dismissing.
        let settled = expectation(description: "abandon settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)

        XCTAssertTrue(sut.hasReachedTerminalState)
        XCTAssertTrue(harness.flowEvents.isEmpty)
        wait(for: [dismissed], timeout: 1)
    }
}

// MARK: - Per-step presentation

extension TooltipPagingTests {

    func testAdvance_appliesTheNextStepsPresentation() {
        let sut = makeRevealedController(stepCount: 2, presentations: [
            TooltipFixture.presentation(pointerEnabled: false),
            TooltipFixture.presentation(pointerEnabled: true)
        ])
        XCTAssertNil(sut.wrapperView.pointerSize)

        sut.handleAction(nil)

        XCTAssertNotNil(sut.wrapperView.pointerSize)
    }

    func testAdvance_wiresAStepOneOnlyTargetTapAction() {
        // With no close button this hotspot is the step's only exit, so failing to
        // wire it strands the user behind a blocking backdrop.
        let sut = makeRevealedController(
            stepCount: 2,
            presentations: [nil, TooltipFixture.presentation(targetTapAction: "next")])
        XCTAssertNil(sut.wrapperView.backdropView.onTargetTapped)

        sut.handleAction(nil)

        XCTAssertNotNil(sut.wrapperView.backdropView.onTargetTapped)
    }

    func testAdvance_clearsAStepZeroOnlyTargetTapAction() {
        let sut = makeRevealedController(
            stepCount: 2,
            presentations: [TooltipFixture.presentation(targetTapAction: "next"), nil])
        XCTAssertNotNil(sut.wrapperView.backdropView.onTargetTapped)

        sut.handleAction(nil)

        XCTAssertNil(sut.wrapperView.backdropView.onTargetTapped)
    }

    // MARK: Mid-segment parking

    func testAdvanceToAParkingStep_leavesTheHostAppUnblocked() {
        // The deadlock guard. `ExperienceOverlayWindow.hitTest` passes touches
        // through only while the presented view is hidden, and a parked step is
        // waiting for a scroll — so a visible wrapper here means the scroll can
        // never happen and the host app is dead for the life of the process.
        let sut = makeController(stepCount: 2, resolvable: ["tooltip-target-0"])
        targeting.isAtEnd = false
        present(sut)
        sut.targetCoordinator.start(retryIntervals: sut.retryIntervals)
        XCTAssertFalse(sut.wrapperView.isHidden)   // step 0 revealed for real

        sut.handleAction(nil)   // step 1's target is not on screen: it parks

        let hidden = expectation(for: NSPredicate { _, _ in sut.wrapperView.isHidden }, evaluatedWith: nil)
        wait(for: [hidden], timeout: 2)
        XCTAssertTrue(sut.isParked)
        XCTAssertFalse(sut.hasReachedTerminalState)
    }

    func testMultiStepSegment_seesEachStepOnce_whenItIsRevealed() {
        let sut = makeRevealedController(stepCount: 3)

        sut.handleAction(nil)   // 0 -> 1, resolves
        sut.handleAction(nil)   // 1 -> 2, resolves

        XCTAssertEqual(stepEvents, [
            "seen_mobile_content_step 0", "completed_mobile_content_step 0",
            "seen_mobile_content_step 1", "completed_mobile_content_step 1",
            "seen_mobile_content_step 2"
        ])
        // The card came back every time.
        XCTAssertFalse(sut.wrapperView.isHidden)
        XCTAssertEqual(sut.viewModel.currentStepIndex, 2)
    }

    func testSingleStepTooltip_revealsAndStaysRevealed() {
        let sut = makeRevealedController(stepCount: 1)

        // A re-resolution, as a scroll or rotation would produce.
        sut.targetCoordinator.start(retryIntervals: sut.retryIntervals)

        XCTAssertFalse(sut.wrapperView.isHidden)
        XCTAssertTrue(sut.hasRevealed)
        XCTAssertEqual(stepEvents, ["seen_mobile_content_step 0"])
    }

    /// The step events sent so far, as `"<event name> <step id>"`.
    private var stepEvents: [String] {
        harness.flowEvents.map { "\($0.eventName) \($0.eventPayload["step_id"] as? Int ?? -1)" }
    }

    /// Presents `sut` from a host that completes dismissals synchronously.
    ///
    /// The unit-test host has no window scene, so UIKit never finishes a real
    /// transition and `dismiss`'s completion — where the terminal events are
    /// emitted — would never run. A presented controller forwards `dismiss` to its
    /// presenter, so the host stands in for the transition.
    func present(_ sut: TooltipViewController) {
        XCTAssertNotNil(sut.admitTargetHost())
        let host = ImmediateDismissHost()
        host.present(sut, animated: false)
        self.host = host
    }

    /// A loaded controller over a fresh `stepCount`-step segment, not yet presented. Only the targets named in
    /// `resolvable` are found.
    func makeController(
        stepCount: Int,
        hasButtonLine: Bool = true,
        deepLinkOnStep: Int? = nil,
        reentryWindow: TimeInterval = 0,
        presentations: [StepPresentation?]? = nil,
        resolvable: Set<String> = []
    ) -> TooltipViewController {
        harness = TooltipTestHarness(flow: TooltipFixture.flowContent(
            stepCount: stepCount, hasButtonLine: hasButtonLine,
            deepLinkOnStep: deepLinkOnStep, stepPresentations: presentations))
        targeting = MockTooltipTargeting(owner: harness.userpilot)
        targeting.resolvableIdentifiers = resolvable
        harness.userpilot.container.registerLazy(
            ElementTargeting.self, initializer: { [targeting] in targeting! })
        let controller = TooltipViewController(viewModel: harness.makeViewModel())
        XCTAssertNotNil(controller.admitTargetHost())
        controller.loadViewIfNeeded()   // runs viewDidLoad -> bindViewModel -> onStart
        // Off by default so tests can page back to back; the double-tap tests opt in.
        controller.advanceReentryWindow = reentryWindow
        // No retries, so a test never waits on the ladder.
        controller.retryIntervals = []
        // Stillness re-reads run at once, so a found target reveals in the same call.
        controller.targetCoordinator.scheduleStillnessCheck = { _, work in work() }
        addTeardownBlock { controller.targetCoordinator.stop() }
        return controller
    }

    /// A presented controller whose step 0 was revealed, so user actions are taken. Every step's target
    /// resolves at once, so each advance reveals the next step in the same call.
    func makeRevealedController(
        stepCount: Int,
        hasButtonLine: Bool = true,
        deepLinkOnStep: Int? = nil,
        reentryWindow: TimeInterval = 0,
        presentations: [StepPresentation?]? = nil
    ) -> TooltipViewController {
        let controller = makeController(
            stepCount: stepCount, hasButtonLine: hasButtonLine, deepLinkOnStep: deepLinkOnStep,
            reentryWindow: reentryWindow, presentations: presentations,
            resolvable: Set((0..<stepCount).map { "tooltip-target-\($0)" }))
        present(controller)
        controller.targetCoordinator.start(retryIntervals: controller.retryIntervals)
        XCTAssertTrue(controller.viewModel.isCurrentStepShown)
        return controller
    }
}
