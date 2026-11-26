//
//  FlowWalk.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Walks one Flow payload segment by segment and projects each segment onto an existing renderer.
//

import Foundation

// MARK: - FlowWalk

/// Walks one Flow payload segment by segment: consecutive tooltip steps form one segment, shown by
/// one tooltip presentation, and every modal or slideout step is a segment alone. Index-based and
/// immutable, so a later Back step can be `index - 1`. Pure: no I/O.
internal struct FlowWalk {
    /// The whole Flow payload received for this screen.
    let flow: FlowContent

    /// The current segment's index in `segments`.
    let index: Int

    /// Consecutive tooltip steps grouped; modal and slideout steps alone; payload order.
    let segments: [[Step]]

    init(flow: FlowContent, index: Int = 0) {
        self.flow = flow
        self.index = index
        self.segments = Self.segments(of: flow.steps)
    }

    /// The current segment as content an existing renderer reads: modal → carousel, slideout → slideout,
    /// tooltip → tooltip. The `FlowSegment` carries what the renderer needs to report the segment's steps.
    func current(screen: String?, run: FlowRun = FlowRun()) -> ExperienceContent {
        let steps = segments[safe: index] ?? []
        // A step without a type shows on the carousel, like a modal.
        let type = steps.first?.stepType?.presenterType ?? .carousel
        let content = FlowContent(
            id: flow.id,
            type: type,
            steps: type == .tooltip ? steps.map { $0.asTooltipStep() } : steps,
            mobileTheme: flow.mobileTheme,
            screens: flow.screens,
            screenType: flow.screenType,
            localeCode: flow.localeCode,
            stepsCount: flow.stepsCount
        )
        let segment = FlowSegment(
            flowId: flow.id, stepsCount: flow.stepsCount ?? flow.steps.count, screen: screen, run: run
        )
        return .flow(content: content, segment: segment)
    }

    /// True once every step of the current segment ended in `run`.
    func isCurrentSegmentEnded(_ run: FlowRun) -> Bool {
        guard let steps = segments[safe: index] else { return false }
        return steps.allSatisfy { run.endedStepIds.contains($0.id) }
    }

    /// The walk at the following segment, or nil when none is left.
    func next() -> FlowWalk? {
        index + 1 < segments.count ? FlowWalk(flow: flow, index: index + 1) : nil
    }

    /// A tooltip step joins the previous segment when that one holds tooltips; any other step starts a segment.
    private static func segments(of steps: [Step]) -> [[Step]] {
        steps.reduce(into: [[Step]]()) { segments, step in
            if step.stepType == .tooltip, segments.last?.last?.stepType == .tooltip {
                segments[segments.count - 1].append(step)
            } else {
                segments.append([step])
            }
        }
    }
}

// MARK: - FlowSegment

/// What a renderer needs to report one segment's steps. The SDK's wrapper, not a wire model.
internal struct FlowSegment: Equatable {
    let flowId: Int

    /// The whole Flow's `steps_count`; the step at this `position` is the Flow's last.
    let stepsCount: Int

    /// The screen the segment was presented on, sent with `mobile_content_error`.
    let screen: String?

    /// The run when the segment was presented; the renderer reports each outcome's next value.
    var run: FlowRun
}
