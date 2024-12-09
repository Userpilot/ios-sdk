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

        /// The delegate object that handles application screen navigation during experience presentation.
        @objc public weak var navigationDelegate: UserpilotNavigationDelegate?

        /// The delegate object that handles application screen navigation during experience presentation.
        @objc public weak var analyticsDelegate: UserpilotAnalyticsDelegate?

        /// The delegate object that manages and observes experience presentations.
        @objc public weak var experienceDelegate: UserpilotExperienceDelegate?

        /// Create an Userpilot SDK configuration
        /// - Parameter accountID: Userpilot Account ID - a string containing an integer,
        ///  copied from the Account settings page in Studio.
        @objc
        public init(token: String) {
            self.token = token
        }

        /// Sets the logging status for the configuration.
        ///
        /// - Parameter enabled: A boolean indicating whether logging is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        ///
        /// Refer to <doc:Logging> for more details about logging functionality.
        @discardableResult
        @objc
        public func logging(_ enabled: Bool) -> Self {
            logger = enabled ? OSLog(userpilotCategory: "general") : .disabled
            return self
        }

        /// Sets the navigation handler for the configuration.
        ///
        /// - Parameter navigationDelegate: An object conforming to the `UserpilotNavigationDelegate` protocol,
        ///   which handles navigation events triggered by Userpilot experiences.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func setNavigationHandler(navigationDelegate: UserpilotNavigationDelegate?) -> Self {
            self.navigationDelegate = navigationDelegate
            return self
        }

        /// Sets the analytics delegate for the configuration.
        ///
        /// - Parameter analyticsDelegate: An object conforming to the `UserpilotAnalyticsDelegate` protocol,
        ///   which listens to analytics events emitted by the SDK.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func setAnalyticsDelegate(analyticsDelegate: UserpilotAnalyticsDelegate?) -> Self {
            self.analyticsDelegate = analyticsDelegate
            return self
        }

        /// Sets the experience delegate for the configuration.
        ///
        /// - Parameter experienceDelegate: An object conforming to the `UserpilotExperienceDelegate` protocol,
        ///   which observes and responds to experience state changes and step events.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func setExperienceDelegate(experienceDelegate: UserpilotExperienceDelegate?) -> Self {
            self.experienceDelegate = experienceDelegate
            return self
        }
    }

}
