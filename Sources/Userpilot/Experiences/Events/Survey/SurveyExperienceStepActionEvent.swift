//
//  SurveyExperienceStepActionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 02/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Builds survey module engagement while preserving the submitted answer's JSON shape.
//

internal enum SurveyExperienceStepActionEvent: ExperienceEvent {
    case seen(surveyId: Int, submissionId: Int64, moduleId: Int, type: String)
    case skipped(surveyId: Int, submissionId: Int64, moduleId: Int, type: String)
    case submitted(surveyId: Int, submissionId: Int64, moduleId: Int, type: String, feedback: Any? = nil)
}

extension SurveyExperienceStepActionEvent {
    var name: SDKEventsName {
        switch self {
        case .seen: return .surveyExperienceStepSeen
        case .skipped: return .surveyExperienceStepSkipped
        case .submitted: return .surveyExperienceStepSubmitted
        }
    }

    var experience: (type: ExperienceType, id: Int)? {
        switch self {
        case .seen(let surveyId, _, _, _), .skipped(let surveyId, _, _, _), .submitted(let surveyId, _, _, _, _):
            return (.survey, surveyId)
        }
    }

    var eventPayload: [String: Any] {
        var payload: [String: Any]
        switch self {
        case let .seen(surveyId, submissionId, moduleId, type),
             let .skipped(surveyId, submissionId, moduleId, type),
             let .submitted(surveyId, submissionId, moduleId, type, _):
            payload = ["survey_id": surveyId, "submission_id": submissionId, "module_id": moduleId, "type": type]
        }
        if case .submitted(_, _, _, _, let feedback) = self {
            payload["feedback"] = feedback
        }
        return payload
    }
}
