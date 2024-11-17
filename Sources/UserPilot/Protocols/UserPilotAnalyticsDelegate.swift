//
//  File.swift
//  
//
//  Created by Motasem Hamed on 16/11/2024.
//

import Foundation

/// The different types of analytics tracked by the SDK.
@objc
public enum UserPilotAnalytic: Int {
    case identify = 0
    case event = 1
    case screen = 2

    public var rawValueString: String {
        switch self {
        case .event:
            return "event"
        case .screen:
            return "screen"
        case .identify:
            return "identify"
        }
    }
}

/// Allows observation of analytics emitted by the SDK.
@objc
public protocol UserPilotAnalyticsDelegate: AnyObject {
    /// Notifies the delegate after Userpilot analytics tracking occurs.
    /// - Parameters:
    ///   - analytic: The type of the analytic.
    ///   - value: Contains the primary value of the analytic being tracked.
    ///    For events - the event name, for screens - the screen title,
    ///   for identify - the user ID.
    ///   - properties: Optional properties that provide additional context
    ///    about the analytic.
    func didTrack(analytic: UserPilotAnalytic, value: String, properties: [String: Any]?)
}
