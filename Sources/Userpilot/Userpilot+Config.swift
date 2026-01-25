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

        /// Enable/Disable UIKit automatic screen tracking
        var uiKitAutoCaptureScreensEnabled: Bool = false

        /// Enable/Disable UIKit automatic click tracking
        var uiKitAutoCaptureClicksEnabled: Bool = false

        /// Enable/Disable SwiftUI automatic screen tracking
        var swiftUIAutoCaptureScreensEnabled: Bool = false

        /// Enable/Disable SwiftUI automatic click tracking
        var swiftUIAutoCaptureClicksEnabled: Bool = false

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
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableRequestPushNotificationsPermission() -> Self {
            self.disableRequestPushPermission = true
            return self
        }

        /// Sets the In-App browser status for the configuration.
        ///
        /// - Parameter enabled: A boolean to Open external link In-app browser using SFSafariViewController.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableUseInAppBrowser(enabled isEnabled: Bool) -> Self {
            useInAppBrowser = isEnabled
            return self
        }

        /// Sets the autoCaptureEnabled for the configuration.
        ///
        /// - Parameter enabled: A boolean to enable auto capture screens and clicks.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableAutoCaptureForUIKit(enabled isEnabled: Bool) -> Self {
            uiKitAutoCaptureScreensEnabled = isEnabled
            uiKitAutoCaptureClicksEnabled = isEnabled
            return self
        }

        /// Sets the autoCaptureEnabled for the configuration.
        ///
        /// - Parameter enabled: A boolean to enable auto capture screens and clicks.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableAutoCaptureForSwiftUI(enabled isEnabled: Bool) -> Self {
            swiftUIAutoCaptureScreensEnabled = isEnabled
            swiftUIAutoCaptureClicksEnabled = isEnabled
            return self
        }

        /// Enables or disables UIKit automatic screen tracking.
        @discardableResult
        @objc
        public func enableUIKitScreenAutoCapture(enabled isEnabled: Bool) -> Self {
            uiKitAutoCaptureScreensEnabled = isEnabled
            return self
        }

        /// Enables or disables UIKit automatic click tracking.
        @discardableResult
        @objc
        public func enableUIKitClickAutoCapture(enabled isEnabled: Bool) -> Self {
            uiKitAutoCaptureClicksEnabled = isEnabled
            return self
        }

        /// Enables or disables SwiftUI automatic screen tracking.
        @discardableResult
        @objc
        public func enableSwiftUIScreenAutoCapture(enabled isEnabled: Bool) -> Self {
            swiftUIAutoCaptureScreensEnabled = isEnabled
            return self
        }

        /// Enables or disables SwiftUI automatic click tracking.
        @discardableResult
        @objc
        public func enableSwiftUIClickAutoCapture(enabled isEnabled: Bool) -> Self {
            swiftUIAutoCaptureClicksEnabled = isEnabled
            return self
        }

    }

}
