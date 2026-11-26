//
//  Constants+Socket.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Phoenix channel keys and push timeout used by socket transport.
//

import Foundation

extension Constants {

    /// Socket transport keys and timeouts (wire format unless noted).
    enum Socket {
        static let successKey = "ok"
        static let errorKey = "error"
        static let timeoutKey = "timeout"

        static let channelTopic = "events:*"
        static let tokenKey = "app_token"
        static let userIdKey = "user_id"
        static let autoPropertiesKey = "auto_properties"
        static let appPropertiesKey = "app_properties"
        static let sdkVersionKey = "sdk_version"

        /// Phoenix push timeout (matches vendored `Defaults.timeoutInterval`).
        static let pushTimeout: TimeInterval = 10.0
    }
}
