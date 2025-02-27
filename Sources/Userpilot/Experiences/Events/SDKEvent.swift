//
//  File.swift
//  
//
//  Created by Motasem Hamed on 24/11/2024.
//

import Foundation

// MARK: - SDKEvent
/**
 Protocol defining the structure for SDK events.
 */
internal protocol SDKEvent {
    var eventName: String { get }
    var eventPayload: [String: Any] { get }
    var hasDeepLink: Bool { get }
}

internal extension SDKEvent {

    var hasDeepLink: Bool {
        return false
    }

    func isEventForCloseExperience() -> Bool {
        return self.eventName == SDKEventsName.flowExperienceDismissed.rawValue ||
        self.eventName == SDKEventsName.flowExperienceCompleted.rawValue ||
        self.eventName == SDKEventsName.surveyExperienceDismissed.rawValue ||
        self.eventName == SDKEventsName.surveyExperienceCompleted.rawValue
    }

    func isEventForCloseNPSExperience() -> Bool {
        return self.eventName == SDKEventsName.npsExperienceDismissed.rawValue
    }

}

internal enum SDKEventsName: String {
    case fetchExperienceContent = "get_mobile_content"
    case fetchExperienceTheme = "fetch_theme"

    case flowExperienceSeen = "seen_mobile_content"
    case flowExperienceDismissed = "dismissed_mobile_content"
    case flowExperienceCompleted = "complete_mobile_content"
    case flowExperienceStepSeen = "seen_mobile_content_step"
    case flowExperienceStepCompleted = "completed_mobile_content_step"

    case surveyExperienceSeen = "seen_survey"
    case surveyExperienceDismissed = "dismissed_survey"
    case surveyExperienceCompleted = "completed_survey"
    case surveyExperienceSubmitted = "completed_survey_module_batch"
    case surveyExperienceStepSeen = "seen_survey_module"
    case surveyExperienceStepSkipped = "skipped_survey_module"
    case surveyExperienceStepSubmitted = "completed_survey_module"

    case npsExperienceSeen = "seen_NPS"
    case npsExperienceDismissed = "dismiss_NPS"
    case npsExperienceSubmitted = "NPS_feedback"
}
