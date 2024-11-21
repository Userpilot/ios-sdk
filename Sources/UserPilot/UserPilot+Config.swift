//
//  Config.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
// [Brief Description]
// Config A configuration object that defines behavior and policies for UserPilot.
//

import Foundation
import UIKit
import os.log

public extension UserPilot {

    // Note: `Config` is a class so that it can be initialized inline with the chained setters. E.g:
    // `Config(token: "TOKEN").logging(true)`. A struct would require initializing as a var first.
    @objc
    class Config: NSObject {

        /// Customer token
        let token: String

        /// UserPilot SDK logger
        var logger: Logging = OSLog.disabled

        /// The delegate object that handles application screen navigation during experience presentation.
        @objc public weak var navigationDelegate: UserPilotNavigationDelegate?

        /// The delegate object that handles application screen navigation during experience presentation.
        @objc public weak var analyticsDelegate: UserPilotAnalyticsDelegate?

        /// The delegate object that manages and observes experience presentations.
        @objc public weak var experienceDelegate: UserPilotExperienceDelegate?

        /// Create an UserPilot SDK configuration
        /// - Parameter accountID: UserPilot Account ID - a string containing an integer,
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
        /// - Parameter navigationDelegate: An object conforming to the `UserPilotNavigationDelegate` protocol,
        ///   which handles navigation events triggered by UserPilot experiences.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func setNavigationHandler(navigationDelegate: UserPilotNavigationDelegate?) -> Self {
            self.navigationDelegate = navigationDelegate
            return self
        }

        /// Sets the analytics delegate for the configuration.
        ///
        /// - Parameter analyticsDelegate: An object conforming to the `UserPilotAnalyticsDelegate` protocol,
        ///   which listens to analytics events emitted by the SDK.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func setAnalyticsDelegate(analyticsDelegate: UserPilotAnalyticsDelegate?) -> Self {
            self.analyticsDelegate = analyticsDelegate
            return self
        }

        /// Sets the experience delegate for the configuration.
        ///
        /// - Parameter experienceDelegate: An object conforming to the `UserPilotExperienceDelegate` protocol,
        ///   which observes and responds to experience state changes and step events.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func setExperienceDelegate(experienceDelegate: UserPilotExperienceDelegate?) -> Self {
            self.experienceDelegate = experienceDelegate
            return self
        }
    }

}
