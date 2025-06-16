//
//  PushNotificationOpenedEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This struct is responsible for defining the event triggered when a push notification is opened.
//

import Foundation

/**
 Represents an event that occurs when a push notification is opened by the user.

 Conforms to `SDKEvent` protocol to standardize event properties within the SDK.

 - Parameters:
   - payload: A dictionary containing the notification's data payload.
 */
internal struct PushNotificationOpenedEvent: SDKEvent {

    // MARK: - Properties

    /// A dictionary containing the push notification payload.
    let payload: [String: Any]

    // MARK: - SDKEvent Conformance

    /// The name of the event.
    ///
    /// Returns the standardized event name for push notification opened events.
    var eventName: String {
        return SDKEventsName.pushNotificationOpened.rawValue
    }

    /// The payload of the event represented as a dictionary.
    ///
    /// Contains the key-value pairs included in the original push notification payload.
    var eventPayload: [String: Any] {
        return payload
    }
}
