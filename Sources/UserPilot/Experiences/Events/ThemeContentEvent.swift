//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation

internal struct ThemeContentEvent: SDKEvent {
    let themeID: Int
    let token: String

    /// The name of the event.
    var eventName: String {
        return "fetch_theme"
    }

    /// The payload of the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return [
            "app_token": token,
            "theme_id": themeID
        ]
    }
}
