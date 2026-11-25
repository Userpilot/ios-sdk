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
    /// Standalone content only; the server derives a Flow's seen from its step events.
    case seen(flowId: Int)
    /// `dismissAction` is the closed Flow step's `settings.dismiss_action`; `nil` outside Flows and when unset.
    case dismissed(flowId: Int, stepId: Int, dismissAction: FlowDismissAction? = nil)
    /// Standalone content only. `hasDeepLink` stays local: it is never part of the payload.
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
        case .seen(let flowId), .dismissed(let flowId, _, _), .completed(let flowId, _):
            return flowId
        }
    }

    var experience: (type: ExperienceType, id: Int)? { (.flow, flowId) }

    var hasDeepLink: Bool {
        guard case .completed(_, let hasDeepLink) = self else { return false }
        return hasDeepLink
    }

    /// Only dismissal includes a step ID, plus `state` when its dismiss action has one;
    /// completion reports the flow as a whole.
    var eventPayload: [String: Any] {
        var payload: [String: Any] = ["mobile_content_id": flowId]
        if case .dismissed(_, let stepId, let dismissAction) = self {
            payload["step_id"] = stepId
            payload["state"] = dismissAction?.dismissState
        }
        return payload
    }
}
