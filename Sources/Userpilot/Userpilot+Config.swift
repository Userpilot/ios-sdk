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

        /// Disables the automatic request for push notification permissions.
        ///
        /// By default, the SDK may prompt the user to grant push notification permissions.
        /// Calling this method prevents the SDK from showing that prompt automatically.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableRequestPushNotificationsPermission() -> Self {
            self.disableRequestPushPermission = true
            return self
        }

    }

}
