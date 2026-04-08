//
//  Config.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// Config A configuration object that defines behavior and policies for Userpilot.
//

import Foundation
import UIKit
import os.log

extension Userpilot {

    // The app framework used by the client application.
    // Used by the SDK for autocapture and lifecycle behavior.
    public enum AppFramework: String {
        case UIKit
        // swiftlint:disable:next identifier_name
        case SwiftUI
    }

    // Note: `Config` is a class so that it can be initialized inline with the chained setters. E.g:
    // `Config(token: "TOKEN").logging(true)`. A struct would require initializing as a var first.
    @objc
    public class Config: NSObject {

        /// Customer token
        let token: String

        /// Userpilot SDK logger
        var logger: Logging = OSLog.disabled

        /// The app framework (UIKit or SwiftUI). Defaults to UIKit.
        var appFramework: AppFramework = .UIKit

        /// Disable request push notifications permission by SDK.
        var disableRequestPushPermission: Bool = false

        /// Open external link In-app browser using SFSafariViewController
        var useInAppBrowser: Bool = false

        // MARK: - Autocapture Configuration Options

        /// Whether or not to enable screen autocapture. Defaults to false.
        /// If set to true, the SDK will automatically capture screen events.
        var enableScreenAutoCapture: Bool = false

        /// Whether or not to enable screen title capture. Defaults to true.
        /// If false, the core SDK will prevent screen titles from being stored or uploaded
        /// and autocapture libraries will be instructed not to capture them.
        var enableScreenTitleCapture: Bool = true

        /// Whether or not to enable interaction autocapture. Defaults to false.
        /// If set to true, the SDK will automatically capture user interactions.
        var enableInteractionAutoCapture: Bool = false

        /// Whether or not to enable user interface text capture. Defaults to true.
        /// If false, the core SDK will prevent user interface text from being stored or uploaded
        /// and autocapture libraries will be instructed not to capture them.
        var enableInteractionTextCapture: Bool = true

        // Whether or not to enable user interface accessibility label capture. Defaults to true.
        // If false, the core SDK will prevent user interface accessibility labels from being
        // stored or uploaded and autocapture libraries will be instructed not to capture them.
        // swiftlint:disable:next identifier_name
        var enableInteractionAccessibilityLabelCapture: Bool = true

        /// Whether or not to enable capturing control values. Defaults to true.
        /// If set to true, the SDK will capture values from controls such as:
        /// - UISwitch: captures the on/off state
        /// - UISegmentedControl: captures the selected segment value
        /// - UISlider: captures the selected value
        /// - UIStepper: captures the selected step value
        /// - UIPickerView: captures the selected value
        /// - UIDatePicker: captures the selected date/time value
        var enableInteractionValueCapture: Bool = false

        /// When true (default), a tap event is not sent for UITextField/UITextView when the action is
        /// a text-editing action (e.g. textChanged:, editingChanged:). Only the text_field_changed /
        /// text_view_changed event is sent. Use this to avoid duplicate events when
        /// typing in SwiftUI or UIKit text fields.
        var ignoreTapForTextInputEditingActions: Bool = true

        /// When true (default), SwiftUI tap events are not sent for views inside a UINavigationBar
        /// (e.g. back button), so only the UIKit sendAction event is recorded. Use this to avoid
        /// duplicate events when tapping navigation bar buttons in SwiftUI.
        var preferUIKitOverSwiftUIForNavigationBar: Bool = true

        /// Create an Userpilot SDK configuration
        /// - Parameter token: Userpilot Account Token, copied from the Environments settings page.
        @objc
        public init(token: String) {
            self.token = token
        }

        /// Sets the logging status for the configuration.
        ///
        /// - Parameter enabled: A boolean indicating whether logging is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func logging(enabled isEnabled: Bool) -> Self {
            logger = isEnabled ? OSLog(userpilotCategory: GeneralConstants.USERPILOT_LOGGING_CATEOGRY) : .disabled
            return self
        }

        /// Sets the app framework (UIKit or SwiftUI).
        /// - Parameter framework: The framework used by the client app.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        public func appFramework(_ framework: AppFramework) -> Self {
            appFramework = framework
            return self
        }

        /// Disables or enables the automatic request for push notifications permission.
        ///
        /// By default, the SDK may prompt the user to grant push notifications permission.
        /// Set to true to prevent the SDK from showing that prompt automatically.
        /// - Parameter disabled: A boolean indicating whether request permission is disabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableRequestPushNotificationsPermission(_ disabled: Bool = true) -> Self {
            self.disableRequestPushPermission = disabled
            return self
        }

        /// Sets the In-App browser status for the configuration.
        ///
        /// - Parameter enabled: A boolean to Open external link In-app browser using SFSafariViewController.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableUseInAppBrowser(_ enabled: Bool = true) -> Self {
            useInAppBrowser = enabled
            return self
        }

        // MARK: - Autocapture Configuration Options

        /// Enables or disables automatic screen capture.
        /// If enabled, the SDK will automatically capture screen view events.
        /// - Parameter enabled: A boolean indicating whether screen autocapture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableScreenAutoCapture(_ enabled: Bool = true) -> Self {
            enableScreenAutoCapture = enabled
            return self
        }

        /// Enables or disables screen title capture.
        /// Set to false to prevent screen titles from being stored or uploaded.
        /// - Parameter enabled: A boolean indicating whether screen title capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableScreenTitleCapture(_ enabled: Bool = true) -> Self {
            enableScreenTitleCapture = enabled
            return self
        }

        /// Deprecated alias for `enableScreenTitleCapture(_:)`.
        @available(*, deprecated, renamed: "enableScreenTitleCapture(_:)")
        @discardableResult
        @objc(disableScreenTitleCapture:)
        public func disableScreenTitleCapture(_ disabled: Bool = true) -> Self {
            enableScreenTitleCapture(!disabled)
        }

        /// Enables or disables automatic interaction (click) capture.
        /// If enabled, the SDK will automatically capture user interaction events.
        /// - Parameter enabled: A boolean indicating whether interaction autocapture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionAutoCapture(_ enabled: Bool = true) -> Self {
            enableInteractionAutoCapture = enabled
            return self
        }

        /// Enables or disables user interface text capture.
        /// Set to false to prevent user interface text from being stored or uploaded.
        /// - Parameter enabled: A boolean indicating whether text capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionTextCapture(_ enabled: Bool = true) -> Self {
            enableInteractionTextCapture = enabled
            return self
        }

        /// Deprecated alias for `enableInteractionTextCapture(_:)`.
        @available(*, deprecated, renamed: "enableInteractionTextCapture(_:)")
        @discardableResult
        @objc(disableInteractionTextCapture:)
        public func disableInteractionTextCapture(_ disabled: Bool = true) -> Self {
            enableInteractionTextCapture(!disabled)
        }

        /// Enables or disables user interface accessibility label capture.
        /// Set to false to prevent accessibility labels from being stored or uploaded.
        /// - Parameter enabled: A boolean indicating whether accessibility label capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionAccessibilityLabelCapture(_ enabled: Bool = true) -> Self {
            enableInteractionAccessibilityLabelCapture = enabled
            return self
        }

        /// Deprecated alias for `enableInteractionAccessibilityLabelCapture(_:)`.
        @available(*, deprecated, renamed: "enableInteractionAccessibilityLabelCapture(_:)")
        @discardableResult
        @objc(disableInteractionAccessibilityLabelCapture:)
        public func disableInteractionAccessibilityLabelCapture(_ disabled: Bool = true) -> Self {
            enableInteractionAccessibilityLabelCapture(!disabled)
        }

        /// Enables or disables capturing control values during interaction tracking.
        /// When enabled (default), the SDK will capture values from controls such as:
        /// - UISwitch: on/off state
        /// - UISegmentedControl: selected segment value
        /// - UISlider: selected value
        /// - UIStepper: selected step value
        /// - UIPickerView: selected value
        /// - UIDatePicker: selected date/time value
        /// - Parameter enabled: A boolean indicating whether control value capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionValueCapture(_ enabled: Bool = true) -> Self {
            enableInteractionValueCapture = enabled
            return self
        }

        /// When true (default), tap is not sent for text field/text view editing actions;
        /// only text_field_changed / text_view_changed is sent.
        @discardableResult
        @objc
        public func ignoreTapForTextInputEditingActions(_ ignore: Bool = true) -> Self {
            ignoreTapForTextInputEditingActions = ignore
            return self
        }

        /// When true (default), SwiftUI tap is not sent for navigation bar (e.g. back button);
        /// only the UIKit event is sent.
        @discardableResult
        @objc
        public func preferUIKitOverSwiftUIForNavigationBar(_ prefer: Bool = true) -> Self {
            preferUIKitOverSwiftUIForNavigationBar = prefer
            return self
        }

    }

}
