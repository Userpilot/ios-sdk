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

// MARK: - SDKEvent
/**
 Protocol defining the structure for SDK events.
 */
internal protocol SDKEvent {
    var eventName: String { get }
    var eventPayload: [String: Any] { get }
}

// MARK: - ExperienceActionEvent
/**
 Base class representing various types of experience action events for mobile content.

 - Parameters:
   - mobileContentId: The ID of the mobile content associated with the event.
   - appToken: The client SDK token.
   - userID: The ID of the user associated with the event.
 */
internal class ExperienceActionEvent: SDKEvent {
    let mobileContentID: Int
    let appToken: String
    let userID: String

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
            "mobile_content_id": mobileContentID,
            "app_token": appToken,
            "userid": userID
        ]
    }

    init(mobileContentID: Int, appToken: String, userID: String) {
        self.mobileContentID = mobileContentID
        self.appToken = appToken
        self.userID = userID
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
