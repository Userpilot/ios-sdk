//
//  SurveyExperienceStepActionEvent.swift
//  Userpilot
//
//  Created by Motasem Hamed on 02/02/2025.
//

import Foundation

// MARK: - SurveyExperienceStepActionEvent
/**
 Base class representing various types of experience step action events for mobile content.

 - Parameters:
   - mobileContentId: The Id of the mobile content associated with the event.
   - stepId: The Id of the step associated with the event.
 */
internal class SurveyExperienceStepActionEvent: SurveyExperienceActionEvent {
    let moduleId: Int
    let type: String

    init(
        surveyId: Int,
        submissionId: Int64,
        moduleId: Int,
        type: String
    ) {
        self.moduleId = moduleId
        self.type = type
        super.init(surveyId: surveyId, submissionId: submissionId)
    }

    /// Creates a dictionary representation of the event data, including the step Id.
    ///
    /// - Returns: A dictionary containing the action type, mobile content Id, application token, user Id, and step Id.
    override func toMap() -> [String: Any] {
        var map = super.toMap()
        map["module_id"] = moduleId
        map["type"] = type
        return map
    }
}

// MARK: - FlowExperienceStepActionEvent Subclasses
/**
 Represents the 'seen' step action event.
 */
internal class ExperienceSurveyStepSeenEvent: SurveyExperienceStepActionEvent {
    override var name: String {
        return SDKEventsName.surveyExperienceStepSeen.rawValue
    }
}

/**
 Represents the 'completed' step action event.
 */
internal class ExperienceSurveyStepSkippedEvent: SurveyExperienceStepActionEvent {
    override var name: String {
        return SDKEventsName.surveyExperienceStepSkipped.rawValue
    }
}

/**
 Represents the 'submitted' action event with extra custom parameters.
*/
internal class ExperienceSurveyStepSubmittedEvent: SurveyExperienceStepActionEvent {

    // Custom parameters for the Submitted event
    let feedback: Any?

    init(
        surveyId: Int,
        submissionId: Int64,
        moduleId: Int,
        type: String,
        feedback: Any? = nil
    ) {
        self.feedback = feedback
        super.init(surveyId: surveyId, submissionId: submissionId, moduleId: moduleId, type: type)
    }

    override var name: String {
        return SDKEventsName.surveyExperienceStepSubmitted.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        if feedback != nil {
            basePayload["feedback"] = feedback
        }
        return basePayload
    }
}
