//
//  ExperienceContentEvent.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 05/11/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This class encapsulates the data required to fetch experience associated with ID.
//

import Foundation

internal struct ExperienceContentEvent: SDKEvent {

    // MARK: - Properties

    let experienceID: String

    // MARK: - SDKEvent Conformance

    /// The name of the event.
    var eventName: String {
        return SDKEventsName.fetchExperienceContent.rawValue
    }

    /// The payload of the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return ["mobile_content_token": experienceID]
    }
}
