//
//  FlowStepEvents.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps each Flow step outcome to its run, host callbacks and backend events.
//

// MARK: - FlowStepOutcome

/// One Flow step outcome: the run's next value, then the host callbacks to fire and the events to publish, in order.
internal struct FlowStepOutcome {
    let run: FlowRun
    let events: [ExperienceEvent]
    let callbacks: [ExperienceCallback]

    /// `link` on the Flow's last step: the renderer records the button's deep link.
    let opensDeepLink: Bool

    init(
        run: FlowRun,
        events: [ExperienceEvent] = [],
        callbacks: [ExperienceCallback] = [],
        opensDeepLink: Bool = false
    ) {
        self.run = run
        self.events = events
        self.callbacks = callbacks
        self.opensDeepLink = opensDeepLink
    }
}

// MARK: - FlowStepEvents

/// Maps a Flow step outcome to the events it sends. Renderers call it when the user's action is committed,
/// before any fade. A Flow sends step events only: never `seen_mobile_content`, `complete_mobile_content` or
/// `dismissed_mobile_content_step`; the server derives those. Nothing is produced after the run ended or for a
/// step that already ended (latch).
internal enum FlowStepEvents {

    /// `step` was revealed: step seen, plus Flow Started when it starts the run.
    static func shown(_ segment: FlowSegment, _ step: Step) -> FlowStepOutcome {
        outcome(segment, step, segment.run.shown(step, stepsCount: segment.stepsCount)) { _ in
            FlowExperienceStepActionEvent.seen(flowId: segment.flowId, stepId: step.id, fromFlowRun: true)
        }
    }

    /// The user advanced past `step` by button or target tap: step completed, plus Flow Completed on the last.
    static func advanced(_ segment: FlowSegment, _ step: Step) -> FlowStepOutcome {
        outcome(segment, step, segment.run.completed(step, stepsCount: segment.stepsCount)) { endsRun in
            FlowExperienceStepActionEvent.completed(flowId: segment.flowId, stepId: step.id, endsRun: endsRun)
        }
    }

    /// Reported like `advanced`; only the Flow's last step opens the link.
    static func linked(_ segment: FlowSegment, _ step: Step) -> FlowStepOutcome {
        let outcome = advanced(segment, step)
        let opensDeepLink = !outcome.events.isEmpty
            && segment.run.isLastStepOfFlow(step, stepsCount: segment.stepsCount)
        return FlowStepOutcome(
            run: outcome.run, events: outcome.events, callbacks: outcome.callbacks, opensDeepLink: opensDeepLink
        )
    }

    /// The user closed `step`; `state` comes from that step's own `settings.dismiss_action`.
    static func closed(_ segment: FlowSegment, _ step: Step) -> FlowStepOutcome {
        outcome(segment, step, segment.run.dismissed(step, stepsCount: segment.stepsCount)) { _ in
            FlowExperienceActionEvent.dismissed(
                flowId: segment.flowId, stepId: step.id, dismissAction: step.settings?.dismissAction
            )
        }
    }

    /// `step`'s target can't be used; `issue` is one of the fixed resolution issues.
    static func failed(_ segment: FlowSegment, _ step: Step, issue: String) -> FlowStepOutcome {
        outcome(segment, step, segment.run.errored(step, stepsCount: segment.stepsCount)) { endsRun in
            FlowContentErrorEvent(
                flowId: segment.flowId, stepId: step.id, issue: issue, screen: segment.screen, endsRun: endsRun
            )
        }
    }

    /// `event` is told whether this outcome ends the run, so analytics can see the run end from the event.
    private static func outcome(
        _ segment: FlowSegment,
        _ step: Step,
        _ next: (run: FlowRun, callbacks: [ExperienceCallback]),
        _ event: (_ endsRun: Bool) -> ExperienceEvent
    ) -> FlowStepOutcome {
        guard segment.run.acceptsOutcome(step) else { return FlowStepOutcome(run: segment.run) }
        return FlowStepOutcome(run: next.run, events: [event(next.run.hasEnded)], callbacks: next.callbacks)
    }
}
