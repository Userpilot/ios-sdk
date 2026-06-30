//
//  ParsedNotification.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This struct is responsible for parsing and holding notification data received from Userpilot experiences.
//

import Foundation

// MARK: - UserpilotNotification
/**
 A data structure to represent the parsed notification response from a Userpilot experience.

 Initializes from a `userInfo` dictionary typically received in a push notification payload.

 - Parameters:
   - title: The title of the notification.
   - body: The body text of the notification.
   - notificationType: Type of the notification.
   - notificationId: The unique identifier of the notification.
   - appToken: The app token associated with the notification.
   - userId: The Id of the user associated with the notification.
   - deeplink: An optional deep link URL, if provided.
 */
internal struct UserpilotNotification {

    // MARK: - Properties

    /// The type of the notification.
    let notificationType: String

    /// The unique identifier of the notification.
    let notificationId: String

    /// The app token associated with the notification.
    let appToken: String?

    /// The user Id associated with the notification.
    let userId: String

    /// An optional deep link URL contained in the notification.
    let deeplink: URL?

    /// An optional is test flag for testing notification.
    let isTest: String?

    // MARK: - Initializer

    /**
     Initializes a `UserpilotNotification` instance by parsing the provided `userInfo` dictionary.

     - Parameter userInfo: A dictionary containing the notification payload.
     - Returns: An optional `UserpilotNotification` instance. Returns `nil` if required fields are missing.
     */
    init?(userInfo: [AnyHashable: Any]) {
        guard
            let data = userInfo["data"] as? [String: Any],
            let notificationType = data["notification_type"] as? String,
            let notificationId = data["notification_id"] as? String,
            let userId = data["user_id"] as? String
        else { return nil }

        self.notificationType = notificationType
        self.notificationId = notificationId
        self.appToken = data["app_token"] as? String
        self.userId = userId

        self.deeplink = (data["deep_link"] as? String).flatMap { URL(string: $0) }
        self.isTest = data["is_test"] as? String
    }
}
