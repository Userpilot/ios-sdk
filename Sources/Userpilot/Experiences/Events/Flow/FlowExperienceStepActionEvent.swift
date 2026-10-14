//
//  FlowExperienceStepActionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Builds flow step engagement without treating step completion as flow completion.
//

internal enum FlowExperienceStepActionEvent: ExperienceEvent {
    case seen(flowId: Int, stepId: Int)
    case completed(flowId: Int, stepId: Int)
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
        case let .seen(flowId, stepId), let .completed(flowId, stepId):
            return (flowId, stepId)
        }
    }

    var experience: (type: ExperienceType, id: Int)? { (.flow, identity.flowId) }

    var eventPayload: [String: Any] {
        return ["mobile_content_id": identity.flowId, "step_id": identity.stepId]
    }
}
