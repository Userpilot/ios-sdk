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

public extension Userpilot {

    // Note: `Config` is a class so that it can be initialized inline with the chained setters. E.g:
    // `Config(token: "TOKEN").logging(true)`. A struct would require initializing as a var first.
    @objc
    class Config: NSObject {

        /// Customer token
        let token: String

        /// Userpilot SDK logger
        var logger: Logging = OSLog.disabled

        /// Disable request push notifications permission by SDK.
        var disableRequestPushPermission: Bool = false

        /// Open external link In-app browser using SFSafariViewController
        var useInAppBrowser: Bool = false

        // MARK: - Autocapture Configuration Options

        /// Whether or not to enable screen autocapture. Defaults to false.
        /// If set to true, the SDK will automatically capture screen events.
        var enableScreenAutocapture: Bool = false

        /// Whether or not to disable screen title capture. Defaults to false.
        /// If set, the core SDK will prevent screen titles from being stored or uploaded
        /// and autocapture libraries will be instructed not to capture them.
        var disableScreenTitleCapture: Bool = false

        /// Whether or not to enable interaction autocapture. Defaults to false.
        /// If set to true, the SDK will automatically capture user interactions.
        var enableInteractionAutocapture: Bool = false

        /// Whether or not to disable user interface text capture. Defaults to false.
        /// If set, the core SDK will prevent user interface text from being stored or uploaded
        /// and autocapture libraries will be instructed not to capture them.
        var disableInteractionTextCapture: Bool = false

        // Whether or not to disable user interface accessibility label capture. Defaults to false.
        // If set, the core SDK will prevent user interface accessibility labels from being
        // stored or uploaded and autocapture libraries will be instructed not to capture them.
        // swiftlint:disable:next identifier_name
        var disableInteractionAccessibilityLabelCapture: Bool = false

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
            logger = isEnabled ? OSLog(userpilotCategory: Constants.General.userpilotLoggingCategory) : .disabled
            return self
        }

        /// Disables the automatic request for push notifications permission.
        ///
        /// By default, the SDK may prompt the user to grant push notifications permission.
        /// Calling this method prevents the SDK from showing that prompt automatically.
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
        public func enableScreenAutocapture(_ enabled: Bool = true) -> Self {
            enableScreenAutocapture = enabled
            return self
        }

        /// Disables screen title capture.
        /// If set, the SDK will prevent screen titles from being stored or uploaded.
        /// - Parameter disabled: A boolean indicating whether screen title capture is disabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableScreenTitleCapture(_ disabled: Bool = true) -> Self {
            disableScreenTitleCapture = disabled
            return self
        }

        /// Enables or disables automatic interaction (click) capture.
        /// If enabled, the SDK will automatically capture user interaction events.
        /// - Parameter enabled: A boolean indicating whether interaction autocapture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionAutocapture(_ enabled: Bool = true) -> Self {
            enableInteractionAutocapture = enabled
            return self
        }

        /// Disables user interface text capture.
        /// If set, the SDK will prevent user interface text from being stored or uploaded.
        /// - Parameter disabled: A boolean indicating whether text capture is disabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableInteractionTextCapture(_ disabled: Bool = true) -> Self {
            disableInteractionTextCapture = disabled
            return self
        }

        /// Disables user interface accessibility label capture.
        /// If set, the SDK will prevent user interface accessibility labels from being stored or uploaded.
        /// - Parameter disabled: A boolean indicating whether accessibility label capture is disabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableInteractionAccessibilityLabelCapture(_ disabled: Bool = true) -> Self {
            disableInteractionAccessibilityLabelCapture = disabled
            return self
        }

    }

}
