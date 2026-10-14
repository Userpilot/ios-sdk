//
//  FetchExperienceEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Builds the backend content request for a manually triggered experience.
//

/// Sent by ExperiencesPublisher.triggerExperience through the internal analytics request path.
internal struct FetchExperienceEvent: SDKEvent {

    // MARK: - Properties

    let experienceId: String

    // MARK: - SDKEvent Conformance

    /// The name of the event.
    var eventName: String {
        return SDKEventsName.fetchExperienceContent.rawValue
    }

    /// The payload of the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return ["mobile_content_token": experienceId]
    }
}
