//
//  PushNotificationTokenEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This struct is responsible for defining the event for registering the push notification device token.
//

import Foundation

/**
 Represents an event that captures and sends the device's push notification token to the server.

 Conforms to `SDKEvent` protocol to standardize event properties within the SDK.

 - Parameters:
   - appToken: The application token identifying the app instance.
   - userId: The user ID associated with the device.
   - token: The push notification device token.
 */
internal struct PushNotificationTokenEvent: SDKEvent {

    // MARK: - Properties

    /// The application token identifying the app instance.
    let appToken: String

    /// The user ID associated with the device.
    let userId: String

    /// The push notification device token.
    let token: String

    // MARK: - SDKEvent Conformance

    /// The name of the event.
    ///
    /// Returns the standardized event name for push notification token events.
    var eventName: String {
        return SDKEventsName.pushNotificationToken.rawValue
    }

    /// The payload of the event represented as a dictionary.
    ///
    /// Contains the application token, user ID, and device token.
    var eventPayload: [String: Any] {
        return ["app_token": appToken, "user_id": userId, "token": token]
    }
}
