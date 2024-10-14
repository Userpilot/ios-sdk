//
//  NotificationCenter+Extension.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `NotificationCenter+Extension` contains extensions with helper methods for the `NotificationCenter`
//  and `Notification` classes.
//  These extensions provide additional functionality for managing notifications and their associated data.
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
