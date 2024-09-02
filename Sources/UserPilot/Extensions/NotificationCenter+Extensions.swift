//
//  NotificationCenter+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// NotificationCenter+Data contains extensions helper methods
//

import Foundation

extension NotificationCenter {

    static var userpilot = NotificationCenter()
}

extension Notification {

    static func toInfo<T>(_ value: T) -> [String: T] { return ["key": value] }

    func value<T>() -> T? {

        guard let info = self.userInfo as? [String: T],
            let oper = info["key"] else {
            return nil
        }

        return oper
    }

}

extension Notification.Name {
    internal static let userpilotTrackedScreen = Notification.Name("userpilotTrackedScreen")
    internal static let userpilotTrackedButton = Notification.Name("userpilotTrackedButton")
}
