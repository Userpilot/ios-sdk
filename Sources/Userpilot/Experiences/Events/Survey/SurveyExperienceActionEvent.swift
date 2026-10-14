//
//  SurveyExperienceActionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Builds survey engagement and batch-answer payloads, preserving optional fields.
//

internal enum SurveyExperienceActionEvent: ExperienceEvent {
    case seen(surveyId: Int, submissionId: Int64)
    case dismissed(surveyId: Int, submissionId: Int64, moduleId: Int?, type: String?)
    case completed(surveyId: Int, submissionId: Int64, hasDeepLink: Bool = false)
    case submitted(surveyId: Int, submissionId: Int64, feedback: Any? = nil)
}

extension SurveyExperienceActionEvent {
    var name: SDKEventsName {
        switch self {
        case .seen: return .surveyExperienceSeen
        case .dismissed: return .surveyExperienceDismissed
        case .completed: return .surveyExperienceCompleted
        case .submitted: return .surveyExperienceSubmitted
        }
    }

    private var identity: (surveyId: Int, submissionId: Int64) {
        switch self {
        case let .seen(surveyId, submissionId), let .dismissed(surveyId, submissionId, _, _),
             let .completed(surveyId, submissionId, _), let .submitted(surveyId, submissionId, _):
            return (surveyId, submissionId)
        }
    }

    var experience: (type: ExperienceType, id: Int)? { (.survey, identity.surveyId) }

    var hasDeepLink: Bool {
        guard case .completed(_, _, let hasDeepLink) = self else { return false }
        return hasDeepLink
    }

    /// Nil fields are omitted, while explicit nulls and structured feedback retain their value.
    var eventPayload: [String: Any] {
        var payload: [String: Any] = ["survey_id": identity.surveyId, "submission_id": identity.submissionId]
        switch self {
        case let .dismissed(_, _, moduleId, type):
            payload["module_id"] = moduleId
            payload["type"] = type
        case let .submitted(_, _, feedback):
            payload["feedback"] = feedback
        case .seen, .completed:
            break
        }
        return payload
    }
}
