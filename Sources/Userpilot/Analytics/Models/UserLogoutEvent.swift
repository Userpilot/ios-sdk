//
//  UserLogoutEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/04/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Reports logout for the outgoing user's push-token association.
//

/// Reports logout for the outgoing user's push-token association.
/// AnalyticsPublisher owns local state cleanup and socket closure.
internal struct UserLogoutEvent: SDKEvent {
    let appToken: String
    let userId: String
    let token: String

    var eventName: String {
        return SDKEventsName.userLogout.rawValue
    }

    var eventPayload: [String: Any] {
        return ["app_token": appToken, "user_id": userId, "token": token]
    }
}
