//
//  NPSExperienceActionEvent.swift
//  Userpilot
//
//  Created by Motasem Hamed on 09/02/2025.
//

import Foundation

// MARK: - SurveyExperienceActionEvent
/**
 Base class representing various types of experience action events for mobile content.
 */
internal class NPSExperienceActionEvent: SDKEvent {
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

    /// Creates a dictionary representation of the event data.
    func toMap() -> [String: Any] {
        return [:]
    }

    init() {
    }
}

// MARK: - NPSExperienceActionEvent Subclasses
/**
 Represents the 'seen' action event.
 */
internal class ExperienceNPSSeenEvent: NPSExperienceActionEvent {
    override var name: String {
        return SDKEventsName.npsExperienceSeen.rawValue
    }
}

/**
 Represents the 'dismissed' action event.
 */
internal class ExperienceNPSDismissedEvent: NPSExperienceActionEvent {
    override var name: String {
        return SDKEventsName.npsExperienceDismissed.rawValue
    }
}

/**
 Represents the 'submitted' action event with extra custom parameters.
*/
internal class ExperienceNPSSubmittedEvent: NPSExperienceActionEvent {

    // Custom parameters for the Submitted event
    var score: Int
    var npsKey: String
    var feedback: Any?
    var feedbackKey: String

    init(
        score: Int,
        npsKey: String,
        feedback: Any?,
        feedbackKey: String
    ) {
        self.score = score
        self.npsKey = npsKey
        self.feedback = feedback
        self.feedbackKey = feedbackKey
    }

    override var name: String {
        return SDKEventsName.npsExperienceSubmitted.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        basePayload["score"] = score
        basePayload["survey_question_key"] = npsKey
        basePayload["feedback"] = feedback
        basePayload["follow_up_question_key"] = feedbackKey
        return basePayload
    }
}
