//
//  ConfigFlag.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Describes the SDK options exposed by the sample configuration screen.
//

import Foundation

enum ConfigFlag: String, CaseIterable, Identifiable {
    case loggingEnabled
    case useInAppBrowser
    case defaultInstance
    case allowReceiveEventsFromExternalSource
    case disableRequestPushNotificationsPermission
    case enableScreenAutoCapture
    case enableInteractionAutoCapture
    case enableInteractionTextCapture
    case enableInteractionAccessibilityLabelCapture
    case enableInteractionValueCapture
    case enableScreenTitleCapture
    case enableSwiftUIButtonAutoCapture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loggingEnabled: return "Logging"
        case .useInAppBrowser: return "In-app browser"
        case .defaultInstance: return "Default instance"
        case .allowReceiveEventsFromExternalSource: return "Receive external events"
        case .disableRequestPushNotificationsPermission: return "Manage push permission in the app"
        case .enableScreenAutoCapture: return "Screen autocapture"
        case .enableInteractionAutoCapture: return "Interaction autocapture"
        case .enableInteractionTextCapture: return "Capture visible text"
        case .enableInteractionAccessibilityLabelCapture: return "Capture accessibility labels"
        case .enableInteractionValueCapture: return "Capture interaction values"
        case .enableScreenTitleCapture: return "Capture screen titles"
        case .enableSwiftUIButtonAutoCapture: return "SwiftUI button capture"
        }
    }

    var description: String {
        switch self {
        case .loggingEnabled: return "Show SDK diagnostic logs while testing."
        case .useInAppBrowser: return "Open experience links inside the app."
        case .defaultInstance: return "Capture screens without an explicit owner."
        case .allowReceiveEventsFromExternalSource: return "Forward events from embedded SDK instances to the default instance."
        case .disableRequestPushNotificationsPermission: return "Prevent the SDK from requesting push permission."
        case .enableScreenAutoCapture: return "Capture screen changes automatically."
        case .enableInteractionAutoCapture: return "Capture taps and value changes automatically."
        case .enableInteractionTextCapture: return "Include visible text in interaction events."
        case .enableInteractionAccessibilityLabelCapture: return "Include accessibility labels in interaction events."
        case .enableInteractionValueCapture: return "Include control values such as switch states and slider positions."
        case .enableScreenTitleCapture: return "Include screen titles in analytics."
        case .enableSwiftUIButtonAutoCapture: return "Resolve titles for SwiftUI buttons on iOS 26 and later."
        }
    }

    var defaultValue: Bool {
        self != .allowReceiveEventsFromExternalSource && self != .disableRequestPushNotificationsPermission
    }
}
