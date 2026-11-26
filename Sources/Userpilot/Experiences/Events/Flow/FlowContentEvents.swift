//
//  FlowContentEvents.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps standalone content's engagement to its host callbacks and backend events.
//

/// Maps standalone content (a carousel or slideout outside a Flow walk) to its host callbacks and the events
/// it sends, in order. Standalone content sends Flow-level and step-level events itself; a Flow walk step reports
/// through `FlowStepEvents`. Steps are numbered by page among the content's own steps.
internal enum FlowContentEvents {

    /// The content opened on its first step: Flow seen, then that step seen. Nothing without a first step.
    static func opened(_ content: FlowContent) -> ExperienceReport {
        guard let first = content.steps.first else { return ExperienceReport() }
        return ExperienceReport(
            callbacks: [
                .experienceState(.started),
                .stepState(.started, stepId: first.id, position: 1, stepsCount: content.steps.count)
            ],
            events: [
                FlowExperienceActionEvent.seen(flowId: content.id),
                FlowExperienceStepActionEvent.seen(flowId: content.id, stepId: first.id)
            ]
        )
    }

    /// Paging reached `page` as a new furthest page: the step before it completed, then its step seen.
    /// Nothing unless both steps exist.
    static func paged(_ content: FlowContent, page: Int) -> ExperienceReport {
        guard
            let previous = content.steps[safe: page - 1],
            let current = content.steps[safe: page]
        else { return ExperienceReport() }
        let count = content.steps.count
        return ExperienceReport(
            callbacks: [
                .stepState(.completed, stepId: previous.id, position: page, stepsCount: count),
                .stepState(.started, stepId: current.id, position: page + 1, stepsCount: count)
            ],
            events: [
                FlowExperienceStepActionEvent.completed(flowId: content.id, stepId: previous.id),
                FlowExperienceStepActionEvent.seen(flowId: content.id, stepId: current.id)
            ]
        )
    }

    /// The last page's action button: the last step completed, then the Flow completed with that step's own link.
    /// Nothing without a last step.
    static func completed(_ content: FlowContent) -> ExperienceReport {
        guard let last = content.steps.last else { return ExperienceReport() }
        let count = content.steps.count
        return ExperienceReport(
            callbacks: [
                .stepState(.completed, stepId: last.id, position: count, stepsCount: count),
                .experienceState(.completed)
            ],
            events: [
                FlowExperienceStepActionEvent.completed(flowId: content.id, stepId: last.id),
                FlowExperienceActionEvent.completed(
                    flowId: content.id,
                    hasDeepLink: !(last.buttonAction?.deepLink?.isEmpty ?? true)
                )
            ]
        )
    }

    /// The user's or the host app's close: the Flow dismissed on the step at `furthestPage`, the furthest one
    /// reached. Nothing when that step doesn't exist.
    static func dismissed(_ content: FlowContent, furthestPage: Int) -> ExperienceReport {
        guard let step = content.steps[safe: furthestPage] else { return ExperienceReport() }
        return ExperienceReport(
            callbacks: [
                .stepState(.dismissed, stepId: step.id, position: furthestPage + 1, stepsCount: content.steps.count),
                .experienceState(.dismissed)
            ],
            events: [FlowExperienceActionEvent.dismissed(flowId: content.id, stepId: step.id)]
        )
    }
}
