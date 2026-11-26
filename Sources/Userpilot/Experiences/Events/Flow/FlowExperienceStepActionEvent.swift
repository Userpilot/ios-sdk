//
//  FlowExperienceStepActionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Builds flow step engagement without treating step completion as flow completion.
//

/// A step's `seen_mobile_content_step` or `completed_mobile_content_step`, carrying `mobile_content_id` and `step_id`.
internal enum FlowExperienceStepActionEvent: ExperienceEvent {
    /// `fromFlowRun` is set by `FlowStepEvents`: a Flow run's step, whose id joins `seen_contents`.
    /// Standalone steps don't. It is never part of the payload.
    case seen(flowId: Int, stepId: Int, fromFlowRun: Bool = false)
    /// `endsRun` is set by `FlowStepEvents`: completing the Flow's last step ended the run, so its error steps
    /// are dropped. It is never part of the payload.
    case completed(flowId: Int, stepId: Int, endsRun: Bool = false)
}

extension FlowExperienceStepActionEvent {
    var name: SDKEventsName {
        switch self {
        case .seen: return .flowExperienceStepSeen
        case .completed: return .flowExperienceStepCompleted
        }
    }

    private var identity: (flowId: Int, stepId: Int) {
        switch self {
        case let .seen(flowId, stepId, _), let .completed(flowId, stepId, _):
            return (flowId, stepId)
        }
    }

    var experience: (type: ExperienceType, id: Int)? { (.flow, identity.flowId) }

    var eventPayload: [String: Any] {
        return ["mobile_content_id": identity.flowId, "step_id": identity.stepId]
    }
}
