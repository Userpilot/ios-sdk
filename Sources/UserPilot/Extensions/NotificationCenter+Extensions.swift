//
//  NotificationCenter+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `NotificationCenter+Data` contains extensions with helper methods for the `NotificationCenter`
//  and `Notification` classes.
//  These extensions provide additional functionality for managing notifications and their associated data.
//
//  Extensions include:
//  - `userpilot`: A static instance of `NotificationCenter` for userpilot-specific notifications.
//  - `toInfo(_:)`: A static method that converts a value to a dictionary with a single key-value pair.
//  - `value<T>()`: A method that retrieves a value of a specified type from the notification's user info dictionary.
//  - `Notification.Name` extensions: Custom notification names for userpilot-specific events.
//

import Foundation

internal extension NotificationCenter {

    static var userpilot = NotificationCenter()
}

internal extension Notification {

    static func toInfo<T>(_ value: T) -> [String: T] { return ["key": value] }

    func value<T>() -> T? {

        guard let info = self.userInfo as? [String: T],
            let oper = info["key"] else {
            return nil
        }

        return oper
    }

}

internal extension Notification.Name {
    static let userpilotTrackedScreen = Notification.Name("userpilotTrackedScreen")
    static let userpilotTrackedButton = Notification.Name("userpilotTrackedButton")
}
