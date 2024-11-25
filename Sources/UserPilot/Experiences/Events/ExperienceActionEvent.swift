//
//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for defining experience events.
//

import Foundation

// MARK: - ExperienceActionEvent
/**
 Base class representing various types of experience action events for mobile content.

 - Parameters:
   - mobileContentId: The ID of the mobile content associated with the event.
   - hasDeepLinkContent: To allow fetch next experience or open deep link screen.
 */
internal class ExperienceActionEvent: SDKEvent {
    let mobileContentID: Int
    let hasDeepLinkContent: Bool

    /// The action type of the event.
    var name: String {
        fatalError("Subclasses need to implement the `act` property.")
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
        return [
            "mobile_content_id": mobileContentID
        ]
    }

    init(mobileContentID: Int, hasDeepLinkContent: Bool = false) {
        self.mobileContentID = mobileContentID
        self.hasDeepLinkContent = hasDeepLinkContent
    }
}

// MARK: - ExperienceActionEvent Subclasses
/**
 Represents the 'seen' action event.
 */
internal class ExperienceSeenEvent: ExperienceActionEvent {
    override var name: String {
        return SDKEventsName.experienceSeen.rawValue
    }
}

/**
 Represents the 'dismissed' action event with extra custom parameters.
*/
internal class ExperienceDismissedEvent: ExperienceActionEvent {

    // Custom parameters for the dismissed event
    let stepId: Int

    init(mobileContentID: Int, stepId: Int) {
        self.stepId = stepId
        super.init(mobileContentID: mobileContentID)
    }

    override var name: String {
        return SDKEventsName.experienceDismissed.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        basePayload["step_id"] = stepId
        return basePayload
    }
}

/**
 Represents the 'completed' action event.
 */
internal class ExperienceCompletedEvent: ExperienceActionEvent {
    override var name: String {
        return SDKEventsName.experienceCompleted.rawValue
    }
}
