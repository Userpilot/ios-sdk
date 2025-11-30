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

    /// Creates a dictionary representation of the event data, including the step Id.
    ///
    /// - Returns: A dictionary containing the action type, mobile content Id, application token, user Id, and step Id.
    override func toMap() -> [String: Any] {
        var map = super.toMap()
        map["module_id"] = moduleId
        map["type"] = type
        return map
    }

    init(
        surveyId: Int,
        moduleId: Int,
        type: String
    ) {
        self.moduleId = moduleId
        self.type = type
        super.init(surveyId: surveyId)
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

    let submissionId: Int64

    init(
        surveyId: Int,
        moduleId: Int,
        type: String,
        submissionId: Int64
    ) {
        self.submissionId = submissionId
        super.init(surveyId: surveyId, moduleId: moduleId, type: type)
    }

    override var name: String {
        return SDKEventsName.surveyExperienceStepSkipped.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        basePayload["submissionId"] = submissionId
        return basePayload
    }
}

/**
 Represents the 'submitted' action event with extra custom parameters.
*/
internal class ExperienceSurveyStepSubmittedEvent: SurveyExperienceStepActionEvent {

    // Custom parameters for the Submitted event
    let submissionId: Int64
    let feedback: Any?

    init(
        surveyId: Int,
        moduleId: Int,
        type: String,
        submissionId: Int64,
        feedback: Any? = nil
    ) {
        self.submissionId = submissionId
        self.feedback = feedback
        super.init(surveyId: surveyId, moduleId: moduleId, type: type)
    }

    override var name: String {
        return SDKEventsName.surveyExperienceStepSubmitted.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        basePayload["submissionId"] = submissionId
        if feedback != nil {
            basePayload["feedback"] = feedback
        }
        return basePayload
    }
}
