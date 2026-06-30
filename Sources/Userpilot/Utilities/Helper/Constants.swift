//
//  Constants.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// Constants hold sdk constants
//

import Foundation

/// dictionary typealias
public typealias Payload = [String: Any]?

// swiftlint:disable identifier_name
internal struct DispatchQueueConstants {
    static let EVENT_QUEUE = "com.userpilot.event-queue"
    static let EXPERIENCE_QUEUE = "com.userpilot.experience-queue"
    static let DELAY_QUEUE = "com.userpilot.delay-queue"
    static let DI_CONTAINER_QUEUE = "com.userpilot.dicontainer-queue"
    static let THROTTLE_QUEUE = "com.userpilot.throttle-queue"
    static let DEBOUNCE_QUEUE = "com.userpilot.debounce-queue"
    static let REGISTRY_QUEUE = "com.userpilot.registry-queue"
}

internal struct GeneralConstants {
    static let PATH_NAME = "/mobile/v1/events/websocket"
    static let SESSION_DURATION = TimeInterval(30 * 60)
    static let CONFIGURATION_DURATION = TimeInterval(30 * 60)
}

internal struct WrapperSDKConstants {
    static let pluginType = "PluginType"
    static let pluginTypeReactNative = "ReactNative"
    static let pluginTypeFlutter = "Flutter"
    static let pluginTypeIonic = "Ionic"
    static let enableScreenAutoCapture = "WrapperEnableScreenAutoCapture"
    static let enableInteractionAutoCapture = "WrapperEnableInteractionAutoCapture"
}

/// Dictionary / JSON keys for Auto Capture payloads (UIKit, SwiftUI helpers, and screen context).
internal struct AutoCaptureConstants {

    // MARK: - Event envelope

    static let internalProperties = "internal_properties"
    static let nestedProperties = "properties"
    static let rawInteractionType = "raw_interaction_type"
    static let uiFramework = "ui_framework"

    // MARK: - Screen context (`buildScreenDictionary` / tracking payload)

    static let screen = "screen"
    static let screenName = "screen_name"
    static let screenClass = "screen_class"
    static let screenTitle = "title"
    static let screenType = "screen_type"
    static let navigationTitle = "navigation_title"
    static let currentScreen = "current_screen"
    static let isUserpilotContainerClass = "is_userpilot_container_class"
    static let vcAccessibilityIdentifier = "vc_accessibility_identifier"
    static let vcAccessibilityLabel = "vc_accessibility_label"

    static let source = "screen_source"
    static let autoCaptureSourceValue = "auto"
    static let manualCaptureSourceValue = "manual"

    static let tabName = "tab_name"
    static let tabIndex = "tab_index"

    /// `true` when a SwiftUI autocaptured screen resolved to the same name/title as the
    /// previous screen context, usually because UIKit exposed a stale navigation title.
    static let screenNameMatchesPreviousScreen = "screen_name_matches_previous_screen"

    // MARK: - Interaction (public properties)

    static let hierarchy = "hierarchy"
    static let interactionType = "interaction_type"
    static let targetClass = "target_class"
    static let targetText = "target_text"
    static let accessibilityLabel = "accessibility_label"
    static let accessibilityIdentifier = "accessibility_identifier"
    static let targetAction = "target_action"
    static let ownerTargetClass = "owner_target_class"
    static let targetViewName = "target_view_name"
    static let placeholder = "placeholder"
    static let dialogTitle = "dialog_title"
    static let dialogMessage = "dialog_message"
    static let section = "section"
    /// used by Flutter
    static let targetPath = "target_path"

    // MARK: - Interaction (source / internal_properties)

    static let isChecked = "is_checked"
    static let selectedIndex = "selected_index"
    static let selectedValue = "selected_value"
    static let selectedDate = "selected_date"
    static let hasText = "has_text"
    static let textLength = "text_length"

    // MARK: - Element tracking payload

    /// Root segment when no owning `UIViewController` is found for a view (`UIView.userpilotResolvedScreenName()`).
    static let unknownScreenHierarchyPlaceholder = "UnknownScreen"

    // MARK: - SwiftUI resolver

    static let swiftUIView = "swiftui_view"

    // MARK: - Common `element_type` values (UIKit)

    static let elementTypeUIAlertController = "UIAlertController"

    // MARK: - Tab bar fallback label

    /// Prefix when `tabBarItem.title` is nil, e.g. `"Tab 1"`.
    static let defaultTabTitlePrefix = "Tab "

    // MARK: - High-frequency interaction debounce (text field, text view, slider)

    /// Quiet period after the last change before emitting a debounced `mobile_autocapture` event.
    static let interactionDebounceInterval: TimeInterval = 1.0

    // MARK: - Values

    static let reductText = "****"
}
// swiftlint:enable identifier_name
