//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation

// MARK: - SDKEventInterface
/**
 Protocol defining the structure for SDK events.
 */
internal protocol SDKEvent {
    var eventName: String { get } // The name of the event.
    var eventPayload: [String: Any] { get } // The payload of the event represented as a dictionary.
}

// MARK: - ExperienceActionEvent
/**
 Base class representing various types of experience action events for mobile content.

 - Parameters:
   - mobileContentId: The ID of the mobile content associated with the event.
   - appToken: The client SDK token.
   - userId: The ID of the user associated with the event.
 */
internal class ExperienceActionEvent: SDKEvent {
    let mobileContentId: Int
    let appToken: String
    let userId: String

    /// The action type of the event.
    var act: String {
        fatalError("Subclasses need to implement the `act` property.")
    }

    /// Event name, defaulted to "mobile_content".
    var eventName: String {
        return "mobile_content"
    }

    /// Payload for the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return toMap()
    }

    /// Creates a dictionary representation of the event data.
    ///
    /// - Returns: A dictionary containing the action type, mobile content ID, application token, and user ID.
    func toMap() -> [String: Any] {
        return [
            "act": act,
            "mobile_content_id": mobileContentId,
            "app_token": appToken,
            "userid": userId
        ]
    }

    init(mobileContentId: Int, appToken: String, userId: String) {
        self.mobileContentId = mobileContentId
        self.appToken = appToken
        self.userId = userId
    }
}

// MARK: - ExperienceActionEvent Subclasses
/**
 Represents the 'seen' action event.
 */
internal class ExperienceSeenEvent: ExperienceActionEvent {
    override var act: String {
        return "seen"
    }
}

/**
 Represents the 'dismissed' action event.
 */
internal class ExperienceDismissedEvent: ExperienceActionEvent {
    override var act: String {
        return "dismissed"
    }
}

/**
 Represents the 'completed' action event.
 */
internal class ExperienceCompletedEvent: ExperienceActionEvent {
    override var act: String {
        return "completed"
    }
}
