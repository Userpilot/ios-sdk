//
//  UserPilotAnalyticsDelegate.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 16/11/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  This protocol allows the application to observe and respond to analytics
//  events emitted by the UserPilot SDK, providing insights into user interactions.
//

import Foundation

/// The different types of analytics tracked by the UserPilot SDK.
@objc
public enum UserPilotAnalytic: Int {
    /// Represents an identify event, typically used to associate a user with a specific ID.
    case identify = 0

    /// Represents a screen tracking event, used to track visits to specific screens.
    case screen = 1

    /// Represents a custom event, used to track specific user interactions or actions.
    case event = 2

    /// Converts the analytic type to its string representation.
    public var rawValueString: String {
        switch self {
        case .identify:
            return "identify"
        case .screen:
            return "screen"
        case .event:
            return "event"
        }
    }
}

/// A protocol that allows observation of analytics events emitted by the UserPilot SDK.
@objc
public protocol UserPilotAnalyticsDelegate: AnyObject {
    /// Notifies the delegate when a UserPilot analytics event is tracked.
    ///
    /// - Parameters:
    ///   - analytic: The type of analytic being tracked. This can be one of:
    ///     - `.identify`: Represents an identify event.
    ///     - `.event`: Represents a custom event.
    ///     - `.screen`: Represents a screen tracking event.
    ///   - value: The primary value associated with the analytic:
    ///     - For `.identify`: The user ID.
    ///     - For `.event`: The event name.
    ///     - For `.screen`: The screen title.
    ///   - properties: Optional dictionary containing additional context or metadata
    ///     about the analytic event.
    func didTrack(analytic: UserPilotAnalytic, value: String, properties: [String: Any]?)
}
