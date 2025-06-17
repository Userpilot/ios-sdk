//
//  UserpilotAnalyticsDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 16/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This protocol allows the application to observe and respond to analytics
//  events emitted by the Userpilot SDK, providing insights into user interactions.
//

import Foundation

/// The different types of analytics tracked by the Userpilot SDK.
@objc
public enum UserpilotAnalytic: Int {
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
            return "Identify"
        case .screen:
            return "Screen"
        case .event:
            return "Event"
        }
    }
}

/// A protocol that allows observation of analytics events emitted by the Userpilot SDK.
@objc
public protocol UserpilotAnalyticsDelegate: AnyObject {
    /// Notifies the delegate when a Userpilot analytics event is tracked.
    ///
    /// - Parameters:
    ///   - analytic: The type of analytic being tracked. This can be one of:
    ///     - `.identify`: Represents an identify event.
    ///     - `.screen`: Represents a screen tracking event.
    ///     - `.event`: Represents a custom event.
    ///   - value: The primary value associated with the analytic:
    ///     - For `.identify`: The user ID.
    ///     - For `.screen`: The screen title.
    ///     - For `.event`: The event name.
    ///   - properties: Optional dictionary containing additional context or metadata
    ///     about the analytic event.
    func didTrack(analytic: UserpilotAnalytic, value: String, properties: [String: Any]?)
}
