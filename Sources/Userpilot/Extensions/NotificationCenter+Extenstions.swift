//
//  NotificationCenter+Extensions.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  NotificationCenter+Extensions provides Userpilot-specific notification handling
//  and convenience methods for SDK-internal communication.
//

import UIKit

/// Extension providing Userpilot-specific notification center functionality
internal extension NotificationCenter {
    // MARK: - Properties

    /// SDK-global notification center for Userpilot internal communication
    /// Note: Use for SDK-global notifications only, prefer DIContainer instance for scoped messages
    static var userpilot = NotificationCenter()
}

/// Extension providing Userpilot-specific notification names
internal extension Notification.Name {
    /// Notification posted when a screen is automatically tracked
    static let userpilotTrackedScreen = Notification.Name("userpilotTrackedScreen")

    /// Notification posted when a click is automatically tracked
    static let userpilotTrackedClick = Notification.Name("userpilotTrackedClick")

    /// Notification posted when a tab selection is tracked
    static let userpilotTrackedTab = Notification.Name("userpilotTrackedTab")

    /// Notification posted when a screen event is manually tracked
    static let userpilotTrackedScreenEvent = Notification.Name("userpilotTrackedScreenEvent")
}

/// Extension providing notification helper methods for typed values
internal extension Notification {
    // MARK: - Static Methods

    /// Creates userInfo dictionary with typed value
    /// - Parameter value: The value to wrap in userInfo
    /// - Returns: Dictionary with the value under "key"
    static func toInfo<T>(_ value: T) -> [String: T] { return ["key": value] }

    // MARK: - Instance Methods

    /// Extracts typed value from notification userInfo
    /// - Returns: The extracted value or nil if not found
    func value<T>() -> T? {

        guard let info = self.userInfo as? [String: T],
            let oper = info["key"] else {
            return nil
        }

        return oper
    }
}

/// Extension providing convenience methods for posting notifications
internal extension NotificationCenter {
    /// Posts notification with a typed value in userInfo
    /// - Parameters:
    ///   - name: The notification name
    ///   - object: The notification object
    ///   - value: The value to include in userInfo
    func post<T>(name: Notification.Name, object: Any?, value: T) {
        self.post(
            name: name,
            object: object,
            userInfo: Notification.toInfo(value)
        )
    }
}
