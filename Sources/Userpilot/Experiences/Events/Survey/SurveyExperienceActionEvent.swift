//
//  SurveyExperienceActionEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for defining survey experience events.
//

import Foundation

// MARK: - SurveyExperienceActionEvent
/**
 Base class representing various types of experience action events for mobile content.

 - Parameters:
   - mobileContentId: The Id of the mobile content associated with the event.
 */
internal class SurveyExperienceActionEvent: SDKEvent {
    /// Experience Id
    let surveyId: Int
    /// Submission Id
    let submissionId: Int64
    /// Has deeplink to open it
    let hasDeepLinkContent: Bool

    /// The action type of the event.
    var name: String {
        fatalError("Subclasses need to implement the `name` property.")
    }

    /// Event name, defaulted to "mobile_content".
    var eventName: String {
        return name
    }

    /// Payload for the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return toMap()
    }

    var hasDeepLink: Bool {
        return hasDeepLinkContent
    }

    /// Creates a dictionary representation of the event data.
    ///
    /// - Returns: A dictionary containing the action type, mobile content Id, application token, and user Id.
    func toMap() -> [String: Any] {
        let params: [String: Any] = [
            "survey_id": surveyId,
            "submission_id": submissionId
        ]
        return params
    }

    init(
        surveyId: Int,
        submissionId: Int64,
        hasDeepLinkContent: Bool = false
    ) {
        self.surveyId = surveyId
        self.submissionId = submissionId
        self.hasDeepLinkContent = hasDeepLinkContent
    }
}

// MARK: - SurveyExperienceActionEvent Subclasses
/**
 Represents the 'seen' action event.
 */
internal class ExperienceSurveySeenEvent: SurveyExperienceActionEvent {
    override var name: String {
        return SDKEventsName.surveyExperienceSeen.rawValue
    }
}

/**
 Represents the 'dismissed' action event.
 */
internal class ExperienceSurveyDismissedEvent: SurveyExperienceActionEvent {
    // Custom parameters for the Submitted event
    let moduleId: Int?
    let type: String?

    init(
        surveyId: Int,
        submissionId: Int64,
        moduleId: Int?,
        type: String?
    ) {
        self.moduleId = moduleId
        self.type = type
        super.init(surveyId: surveyId, submissionId: submissionId)
    }

    override var name: String {
        return SDKEventsName.surveyExperienceDismissed.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        if moduleId != nil {
            basePayload["module_id"] = moduleId
        }
        if type != nil {
            basePayload["type"] = type
        }
        return basePayload
    }
}

/**
 Represents the 'completed' action event.
 */
internal class ExperienceSurveyCompletedEvent: SurveyExperienceActionEvent {
    override var name: String {
        return SDKEventsName.surveyExperienceCompleted.rawValue
    }
}

/**
 Represents the 'submitted' action event with extra custom parameters.
*/
internal class ExperienceSurveySubmittedEvent: SurveyExperienceActionEvent {

    // Custom parameters for the Submitted event
    let feedback: Any?

    init(
        surveyId: Int,
        submissionId: Int64,
        feedback: Any? = nil
    ) {
        self.feedback = feedback
        super.init(surveyId: surveyId, submissionId: submissionId)
    }

    override var name: String {
        return SDKEventsName.surveyExperienceSubmitted.rawValue
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
