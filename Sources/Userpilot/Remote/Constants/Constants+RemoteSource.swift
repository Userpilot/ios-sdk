//
//  Constants+RemoteSource.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Remote endpoints and SDK settings cache duration.
//

import Foundation

extension Constants {

    /// Remote endpoints and settings-cache tuning.
    enum RemoteSource {
        static let settingsBaseURL = "https://find.userpilot.io/v1/lookups/"
        static let socketPath = "/mobile/v1/events/websocket"
        /// How long fetched SDK settings stay fresh before a refetch.
        static let configurationDuration = TimeInterval(30 * 60)
    }
}
