//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation

// MARK: - ExperienceStepActionEvent
/**
 Base class representing various types of experience step action events for mobile content.

 - Parameters:
   - mobileContentId: The ID of the mobile content associated with the event.
   - appToken: The client SDK token.
   - userId: The ID of the user associated with the event.
   - stepId: The ID of the step associated with the event.
 */
internal class ExperienceStepActionEvent: ExperienceActionEvent {
    let stepId: String

    override var eventName: String {
        return "mobile_content_step"
    }

    /// Creates a dictionary representation of the event data, including the step ID.
    ///
    /// - Returns: A dictionary containing the action type, mobile content ID, application token, user ID, and step ID.
    override func toMap() -> [String: Any] {
        var map = super.toMap()
        map["stepId"] = stepId
        return map
    }

    init(mobileContentId: Int, appToken: String, userId: String, stepId: String) {
        self.stepId = stepId
        super.init(mobileContentId: mobileContentId, appToken: appToken, userId: userId)
    }
}

// MARK: - ExperienceStepActionEvent Subclasses
/**
 Represents the 'seen' step action event.
 */
internal class ExperienceStepSeenEvent: ExperienceStepActionEvent {
    override var act: String {
        return "seen"
    }
}

/**
 Represents the 'dismissed' step action event.
 */
internal class ExperienceStepDismissedEvent: ExperienceStepActionEvent {
    override var act: String {
        return "dismissed"
    }
}

/**
 Represents the 'completed' step action event.
 */
internal class ExperienceStepCompletedEvent: ExperienceStepActionEvent {
    override var act: String {
        return "completed"
    }
}
