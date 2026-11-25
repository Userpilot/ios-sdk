//
//  ExperienceViewModelFlowStepTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies where a carousel Flow step fires Flow Started and Flow Completed, and that the publisher has
//  each step outcome before the host delegate hears about it.
//

import XCTest
@testable import Userpilot

extension ExperienceViewModelTests {

    func testAFlowStepShownLaterInTheFlow_firesNoFlowStarted() {
        let delegate = FlowStepDelegate()
        userpilot.experienceDelegate = delegate
        let reported = expectation(description: "seen outcome reported")
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { _ in reported.fulfill() }
        startFlowStep(position: 2)

        viewModel.onExperienceSeen()
        wait(for: [reported], timeout: 2)

        XCTAssertEqual(delegate.flowStates, [])
        XCTAssertEqual(delegate.states, [.started])
        XCTAssertEqual(delegate.positions, [2])
    }

    func testNextOnTheFlowsLastStep_completesTheStep_andFiresFlowCompleted() {
        let delegate = OrderedFlowDelegate()
        userpilot.experienceDelegate = delegate
        var outcomes: [FlowStepOutcome] = []
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { outcomes.append($0) }
        startFlowStep(position: 3)

        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "next", deepLink: nil))

        XCTAssertEqual(outcomes.flatMap { $0.events.map(\.eventName) }, ["completed_mobile_content_step"])
        XCTAssertEqual(outcomes.first?.run.hasEnded, true)
        XCTAssertEqual(delegate.calls, [.step(.completed), .flow(.completed)])
    }

    /// Swift delegates cannot throw, so the order stands in for Android's throwing-listener case.
    func testAFlowStepOutcome_reachesThePublisherBeforeTheHostDelegate() {
        let delegate = OrderedFlowDelegate()
        userpilot.experienceDelegate = delegate
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { _ in delegate.calls.append(.publisher) }
        startFlowStep(position: 3)

        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "next", deepLink: nil))

        XCTAssertEqual(delegate.calls, [.publisher, .step(.completed), .flow(.completed)])
    }
}

/// Records the host callbacks in arrival order, with step and Flow states interleaved.
private final class OrderedFlowDelegate: UserpilotExperienceDelegate {

    enum Call: Equatable {
        case publisher
        case flow(UserpilotExperienceState)
        case step(UserpilotExperienceState)
    }

    var calls: [Call] = []

    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?,
        experienceState: UserpilotExperienceState
    ) {
        calls.append(.flow(experienceState))
    }

    // swiftlint:disable:next function_parameter_count
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    ) {
        calls.append(.step(stepState))
    }
}
