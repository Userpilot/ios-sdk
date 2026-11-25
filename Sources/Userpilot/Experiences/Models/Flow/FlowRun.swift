//
//  FlowRun.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines a Flow's progress on this device and the host callbacks each step outcome fires.
//

import Foundation

// MARK: - FlowRun

/// The Flow's progress on this device, tracked apart from any overlay. The publisher's operation owns it,
/// hands it to each segment through its `FlowSegment`, and keeps the next value of every step outcome.
///
/// Pure and immutable: each outcome function returns the next run and the host callbacks to fire, in
/// order; nothing here touches I/O. After the run ended, or for a step that already ended, an outcome
/// returns this run and no callbacks.
internal struct FlowRun: Equatable {
    /// Steps that completed, were dismissed or failed.
    let endedStepIds: Set<Int>

    /// The Flow's last step completed or failed, the user closed a step, or an `end_flow` error ended it.
    let hasEnded: Bool

    /// The step at `position` 1, or the first step shown after it ended by error, was shown; Started fires once.
    let hasStarted: Bool

    /// The step at `position` 1 ended by error in this run, so the next step shown starts the Flow.
    let hasSkippedFirstStep: Bool

    /// With the defaults, a run that has not started: nothing shown, nothing ended.
    init(
        endedStepIds: Set<Int> = [], hasEnded: Bool = false, hasStarted: Bool = false, hasSkippedFirstStep: Bool = false
    ) {
        self.endedStepIds = endedStepIds
        self.hasEnded = hasEnded
        self.hasStarted = hasStarted
        self.hasSkippedFirstStep = hasSkippedFirstStep
    }

    /// True for the step at `position == steps_count`; completing it or failing on it ends the run.
    func isLastStepOfFlow(_ step: Step, stepsCount: Int) -> Bool {
        step.position == stepsCount
    }

    /// False after the run ended or once `step` ended: such an outcome reports nothing.
    func acceptsOutcome(_ step: Step) -> Bool {
        !hasEnded && !endedStepIds.contains(step.id)
    }

    /// Step Started; Flow Started first when the run hasn't started and `step` is at `position` 1, or is the
    /// first step shown after the `position` 1 step ended by error. A run resumed past `position` 1 never starts.
    func shown(_ step: Step, stepsCount: Int) -> (run: FlowRun, callbacks: [ExperienceCallback]) {
        guard acceptsOutcome(step) else { return (self, []) }
        let starts = !hasStarted && (step.position == 1 || hasSkippedFirstStep)
        let callbacks = (starts ? [ExperienceCallback.experienceState(.started)] : [])
            + [step.callback(.started, stepsCount)]
        let next = FlowRun(endedStepIds: endedStepIds, hasEnded: hasEnded, hasStarted: hasStarted || starts,
                           hasSkippedFirstStep: hasSkippedFirstStep)
        return (next, callbacks)
    }

    /// Step Completed; the Flow's last step also ends the run and fires Flow Completed.
    func completed(_ step: Step, stepsCount: Int) -> (run: FlowRun, callbacks: [ExperienceCallback]) {
        guard acceptsOutcome(step) else { return (self, []) }
        let ends = isLastStepOfFlow(step, stepsCount: stepsCount)
        let callbacks = [step.callback(.completed, stepsCount)]
            + (ends ? [ExperienceCallback.experienceState(.completed)] : [])
        return (ended(step, ends: ends), callbacks)
    }

    /// The user closed `step`: step Dismissed, then Flow Dismissed. The run ends, whatever the step.
    func dismissed(_ step: Step, stepsCount: Int) -> (run: FlowRun, callbacks: [ExperienceCallback]) {
        guard acceptsOutcome(step) else { return (self, []) }
        let callbacks = [step.callback(.dismissed, stepsCount), ExperienceCallback.experienceState(.dismissed)]
        return (ended(step, ends: true), callbacks)
    }

    /// `step`'s target can't be used. `end_flow` ends the run at once; `skip_step`, the default, ends only the step
    /// unless it is the Flow's last. The server completes an errored run, so its end fires Flow Completed once.
    func errored(_ step: Step, stepsCount: Int) -> (run: FlowRun, callbacks: [ExperienceCallback]) {
        guard acceptsOutcome(step) else { return (self, []) }
        let ends = step.settings?.fallback == .endFlow || isLastStepOfFlow(step, stepsCount: stepsCount)
        let callbacks: [ExperienceCallback] = ends ? [.experienceState(.completed)] : []
        return (ended(step, ends: ends, skipsFirstStep: step.position == 1), callbacks)
    }

    /// The run with `step` ended. `ends` ends the run too; `skipsFirstStep` marks the `position` 1 step's error.
    private func ended(_ step: Step, ends: Bool, skipsFirstStep: Bool = false) -> FlowRun {
        FlowRun(endedStepIds: endedStepIds.union([step.id]), hasEnded: ends, hasStarted: hasStarted,
                hasSkippedFirstStep: hasSkippedFirstStep || skipsFirstStep)
    }
}
