//
//  FlowExperienceActionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Defines flow engagement payloads and the local completion deep-link policy.
//

internal enum FlowExperienceActionEvent: ExperienceEvent {
    case seen(flowId: Int)
    case dismissed(flowId: Int, stepId: Int)
    case completed(flowId: Int, hasDeepLink: Bool = false)
}

extension FlowExperienceActionEvent {
    var name: SDKEventsName {
        switch self {
        case .seen: return .flowExperienceSeen
        case .dismissed: return .flowExperienceDismissed
        case .completed: return .flowExperienceCompleted
        }
    }

    private var flowId: Int {
        switch self {
        case .seen(let flowId), .dismissed(let flowId, _), .completed(let flowId, _):
            return flowId
        }
    }

    var experience: (type: ExperienceType, id: Int)? { (.flow, flowId) }

    var hasDeepLink: Bool {
        guard case .completed(_, let hasDeepLink) = self else { return false }
        return hasDeepLink
    }

    /// Only dismissal includes a step ID; completion reports the flow as a whole.
    var eventPayload: [String: Any] {
        var payload: [String: Any] = ["mobile_content_id": flowId]
        if case .dismissed(_, let stepId) = self {
            payload["step_id"] = stepId
        }
        return payload
    }
}
