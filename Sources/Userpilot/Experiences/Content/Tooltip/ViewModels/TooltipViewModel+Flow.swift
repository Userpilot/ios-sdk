//
//  TooltipViewModel+Flow.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Reads a Flow segment's run for the tooltip renderer.
//  The run's outcomes are reported by `TooltipViewModel`, which owns the segment.
//

// MARK: - Flow Mode

internal extension TooltipViewModel {

    /// True once a step outcome ended the Flow's run; nothing more is shown.
    var isFlowRunEnded: Bool {
        flowSegment?.run.hasEnded == true
    }

    /// Whether the step showing now is the Flow's last (`position == steps_count`), the only step whose
    /// outcome ends the run and the only one that may open a link.
    var isLastStepOfFlow: Bool {
        guard let flowSegment, let step = currentTooltipStep else { return false }
        return flowSegment.run.isLastStepOfFlow(step, stepsCount: flowSegment.stepsCount)
    }

    /// Whether completing the step showing now closes the overlay: the segment's last step, or the Flow's last
    /// even when the segment carries steps after it, since its outcome ends the run.
    var completesSegment: Bool {
        isLastStepOfSegment || isLastStepOfFlow
    }

    /// Whether the step showing now was seen; a user action on a step not yet seen does nothing.
    var isCurrentStepShown: Bool {
        shownStepIndex == currentStepIndex
    }
}
