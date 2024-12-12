//
//  ThemeContentEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This structure defines a theme content event used to track the fetching of a specific theme by its ID.
//

import Foundation

internal struct ThemeContentEvent: SDKEvent {

    // MARK: - Properties

    let themeID: Int
    let token: String

    // MARK: - SDKEvent Conformance

    /// The name of the event.
    var eventName: String {
        return SDKEventsName.fetchExperienceTheme.rawValue
    }

    /// The payload of the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return [
            "app_token": token,
            "theme_id": themeID
        ]
    }
}
