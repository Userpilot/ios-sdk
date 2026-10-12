//
//  ThemeContentEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This structure defines a theme content event used to fetch a theme by its ID, or the host app's
//  theme by its title.
//

import Foundation

internal struct ThemeContentEvent: SDKEvent {

    // MARK: - Properties

    let key: ThemeKey
    let token: String

    // MARK: - SDKEvent Conformance

    /// The name of the event.
    var eventName: String {
        return SDKEventsName.fetchExperienceTheme.rawValue
    }

    /// The payload of the event represented as a dictionary.
    var eventPayload: [String: Any] {
        switch key {
        case .id(let themeId):
            return ["app_token": token, "theme_id": themeId]
        case .title(let title):
            return ["app_token": token, "theme_title": title]
        }
    }
}
