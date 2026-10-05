//
//  ExperienceStateMachine+Flow.swift
//  Userpilot SDK
//
//  Created by Userpilot on 03/10/2026.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Tracks rendered flow stages so dismissal and completed experiences can be distinguished.
//

import Foundation

/// Flow progress — what lets a dismissal be told apart from the end of an experience.
///
/// Split from `ExperienceStateMachine` so the state vocabulary and the flow running over it can be
/// read separately. Android holds the same model on its own `ExperienceStateMachine`.
extension ExperienceStateMachine {

    /// One rendered stage of a flow.
    ///
    /// Today a flow is only ever a survey followed by its thank-you message, so two kinds are
    /// enough. The multi-step flow feature adds kinds here rather than reshaping `FlowProgress`.
    enum FlowStep {
        case content
        case thankYou
    }

    /// Where a flow has got to.
    ///
    /// This is what lets `hasNextFlowStep()` answer "is this experience really over?" when a
    /// renderer dismisses, telling the end of a flow apart from the gap between two of its steps.
    struct FlowProgress {
        let steps: [FlowStep]
        var currentIndex: Int = 0

        /// True while a later step is still owed, so the flow is not finished.
        var hasNextStep: Bool { currentIndex < steps.count - 1 }

        func advanced() -> FlowProgress {
            FlowProgress(steps: steps, currentIndex: currentIndex + 1)
        }
    }

    /// Starts tracking the flow `content` runs as, working the steps out from the content itself.
    ///
    /// Keeping the derivation here rather than at the call site means one place decides how many
    /// steps an experience has — the same place that later answers `hasNextFlowStep()`. A caller
    /// that disagreed about that is how a flow gets stranded half-finished.
    func beginFlow(_ content: ExperienceContent) {
        beginFlow(steps: flowSteps(for: content))
    }

    /// Starts tracking a flow of `steps`.
    ///
    /// Backend-defined flows will use this directly; `beginFlow(_:)` is today's derivation for
    /// surveys that end in a thank-you message.
    func beginFlow(steps: [FlowStep]) {
        guard steps.count > 1 else {
            flowProgress.value = nil
            return
        }
        flowProgress.value = FlowProgress(steps: steps)
        logger.info("Experience flow: step 1 of %d", steps.count)
    }

    /// True while the running flow still owes a step, so a dismissal is not the end of it.
    func hasNextFlowStep() -> Bool {
        flowProgress.value?.hasNextStep == true
    }

    /// Moves to the next step. Clears the flow once the last one is reached.
    func advanceFlowStep() {
        guard let current = flowProgress.value else { return }
        guard current.hasNextStep else {
            flowProgress.value = nil
            return
        }
        let next = current.advanced()
        flowProgress.value = next
        logger.info("Experience flow: step %d of %d", next.currentIndex + 1, next.steps.count)
    }

    /// Abandons the running flow, so nothing is owed after the current renderer goes away.
    func clearFlow() {
        flowProgress.value = nil
    }

    /// The steps `content` runs as. Single-step for everything that renders in one go.
    ///
    /// Only a list survey ending in its completed module is a flow today: the questions, then the
    /// thank-you message in a renderer of its own. Backend-defined flows arrive with their steps
    /// already spelled out and call `beginFlow(steps:)` rather than come through here.
    private func flowSteps(for content: ExperienceContent) -> [FlowStep] {
        let hasThankYouStep = content.asSurveyContent()?.modules.last?.type == .completed
        return hasThankYouStep ? [.content, .thankYou] : [.content]
    }
}
