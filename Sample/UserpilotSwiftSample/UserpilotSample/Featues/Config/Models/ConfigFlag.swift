//
//  ConfigFlag.swift
//  UserpilotSample
//
//  Created by Userpilot on 21/07/2026.
//

import Foundation

/// Represents a single boolean flag of the Userpilot SDK `Userpilot.Config`.
///
/// Each case maps an SDK config option to a `UserDefaults` `key` and its
/// `defaultValue`, together with a human readable `title` and a `description`
/// explaining what the flag means for the Userpilot SDK. The Config screen
/// renders one toggle per case and `UserpilotManager` reads the persisted
/// `value` when building the SDK configuration, so the app must be restarted
/// for changes to take effect.
enum ConfigFlag: CaseIterable {

    case loggingEnabled
    case useInAppBrowser
    case allowReceiveEventsFromExternalSource
    // swiftlint:disable:next identifier_name
    case disableRequestPushNotificationsPermission
    case enableScreenAutoCapture
    case enableInteractionAutoCapture
    case enableInteractionTextCapture
    // swiftlint:disable:next identifier_name
    case enableInteractionAccessibilityLabelCapture
    case enableInteractionValueCapture

    /// The `UserDefaults` key used to persist this flag.
    var key: String {
        switch self {
        case .loggingEnabled:
            return "CONFIG_LOGGING_ENABLED"
        case .useInAppBrowser:
            return "CONFIG_USE_IN_APP_BROWSER"
        case .allowReceiveEventsFromExternalSource:
            return "CONFIG_ALLOW_RECEIVE_EVENTS_FROM_EXTERNAL_SOURCE"
        case .disableRequestPushNotificationsPermission:
            return "CONFIG_DISABLE_REQUEST_PUSH_NOTIFICATIONS_PERMISSION"
        case .enableScreenAutoCapture:
            return "CONFIG_ENABLE_SCREEN_AUTO_CAPTURE"
        case .enableInteractionAutoCapture:
            return "CONFIG_ENABLE_INTERACTION_AUTO_CAPTURE"
        case .enableInteractionTextCapture:
            return "CONFIG_ENABLE_INTERACTION_TEXT_CAPTURE"
        case .enableInteractionAccessibilityLabelCapture:
            return "CONFIG_ENABLE_INTERACTION_ACCESSIBILITY_LABEL_CAPTURE"
        case .enableInteractionValueCapture:
            return "CONFIG_ENABLE_INTERACTION_VALUE_CAPTURE"
        }
    }

    /// Human readable title matching the SDK config option name.
    var title: String {
        switch self {
        case .loggingEnabled:
            return "loggingEnabled"
        case .useInAppBrowser:
            return "useInAppBrowser"
        case .allowReceiveEventsFromExternalSource:
            return "allowReceiveEventsFromExternalSource"
        case .disableRequestPushNotificationsPermission:
            return "disableRequestPushNotificationsPermission"
        case .enableScreenAutoCapture:
            return "enableScreenAutoCapture"
        case .enableInteractionAutoCapture:
            return "enableInteractionAutoCapture"
        case .enableInteractionTextCapture:
            return "enableInteractionTextCapture"
        case .enableInteractionAccessibilityLabelCapture:
            return "enableInteractionAccessibilityLabelCapture"
        case .enableInteractionValueCapture:
            return "enableInteractionValueCapture"
        }
    }

    /// Explanation of what the flag does for the Userpilot SDK.
    var description: String {
        switch self {
        case .loggingEnabled:
            return "Enables verbose SDK logs in the Xcode console. Turn on while integrating "
                + "to debug Userpilot behaviour; keep it off in production."
        case .useInAppBrowser:
            return "Opens experience/URL links inside an in-app SFSafariViewController instead "
                + "of an external browser."
        case .allowReceiveEventsFromExternalSource:
            return "When set on the default (host) instance, autocapture events coming from "
                + "embedded/vendor instances are also forwarded to this instance's analytics."
        case .disableRequestPushNotificationsPermission:
            return "Prevents the SDK from requesting the push notifications permission. Enable "
                + "it when your app manages the permission itself."
        case .enableScreenAutoCapture:
            return "Automatically tracks UIViewController screen views (UIKit apps) without "
                + "manual screen() calls."
        case .enableInteractionAutoCapture:
            return "Automatically captures user interactions (taps and value changes) as "
                + "events (UIKit apps)."
        case .enableInteractionTextCapture:
            return "Includes the visible text/labels of tapped views in autocapture events. "
                + "Disable it to avoid capturing PII or sensitive data."
        case .enableInteractionAccessibilityLabelCapture:
            return "Includes accessibility labels of views in autocapture events. Use it "
                + "together with text capture for richer element targeting."
        case .enableInteractionValueCapture:
            return "Captures value payloads for change events (switch state, slider/segment "
                + "values, selected date/time and picker selections)."
        }
    }

    /// The default value used when the flag has never been persisted.
    var defaultValue: Bool {
        switch self {
        case .loggingEnabled,
             .useInAppBrowser,
             .enableScreenAutoCapture,
             .enableInteractionAutoCapture,
             .enableInteractionTextCapture,
             .enableInteractionAccessibilityLabelCapture,
             .enableInteractionValueCapture:
            return true
        case .allowReceiveEventsFromExternalSource,
             .disableRequestPushNotificationsPermission:
            return false
        }
    }

    /// The persisted value for this flag, falling back to `defaultValue` when never saved.
    var value: Bool {
        StorageManager.shared.bool(forKey: key, default: defaultValue)
    }
}
