//
//  NPSExperienceActionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Defines NPS engagement with immutable inputs and its existing feedback payload.
//

internal enum NPSExperienceActionEvent: ExperienceEvent {
    case seen
    case dismissed
    case submitted(score: Int, npsKey: String, feedback: Any?, feedbackKey: String)
}

extension NPSExperienceActionEvent {
    var name: SDKEventsName {
        switch self {
        case .seen: return .npsExperienceSeen
        case .dismissed: return .npsExperienceDismissed
        case .submitted: return .npsExperienceSubmitted
        }
    }

    /// NPS does not participate in flow/survey seen IDs or post-dismissal screen refreshes.
    var experience: (type: ExperienceType, id: Int)? { nil }

    var eventPayload: [String: Any] {
        guard case let .submitted(score, npsKey, feedback, feedbackKey) = self else { return [:] }
        var payload: [String: Any] = [
            "score": score,
            "survey_question_key": npsKey,
            "follow_up_question_key": feedbackKey
        ]
        payload["feedback"] = feedback
        return payload
    }
}
