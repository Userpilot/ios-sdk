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
   - mobileContentId: The ID of the mobile content associated with the event.
   - stepID: The ID of the step associated with the event.
 */
internal class SurveyExperienceStepActionEvent: SurveyExperienceActionEvent {
    let moduleID: Int
    let type: String

    /// Creates a dictionary representation of the event data, including the step ID.
    ///
    /// - Returns: A dictionary containing the action type, mobile content ID, application token, user ID, and step ID.
    override func toMap() -> [String: Any] {
        var map = super.toMap()
        map["module_id"] = moduleID
        map["type"] = type
        return map
    }

    init(surveyID: Int, moduleID: Int, type: String) {
        self.moduleID = moduleID
        self.type = type
        super.init(surveyID: surveyID)
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

    init(surveyID: Int, moduleID: Int, type: String, feedback: Any? = nil) {
        self.feedback = feedback
        super.init(surveyID: surveyID, moduleID: moduleID, type: type)
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
