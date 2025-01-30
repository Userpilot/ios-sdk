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
   - mobileContentId: The ID of the mobile content associated with the event.
 */
internal class SurveyExperienceActionEvent: SDKEvent {
    /// Experience ID
    let surveyID: Int
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
    /// - Returns: A dictionary containing the action type, mobile content ID, application token, and user ID.
    func toMap() -> [String: Any] {
        var params: [String: Any] = [
            "survey_id": surveyID
        ]
        return params
    }

    init(surveyID: Int, hasDeepLinkContent: Bool = false) {
        self.surveyID = surveyID
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
    override var name: String {
        return SDKEventsName.surveyExperienceDismissed.rawValue
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

    init(surveyID: Int, feedback: Any? = nil) {
        self.feedback = feedback
        super.init(surveyID: surveyID)
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
