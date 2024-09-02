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
    class Config: NSObject {

        /// Customer token
        let token: String

        /// UserPilot SDK settings URL
        let settingsHost: URL = NetworkClient.defaultSettingsHost

        /// Network session base URL
        let urlSession: URLSession = NetworkClient.defaultURLSession

        /// UserPilot SDK logger
        var logger: Logging = OSLog.disabled

        /// default customer properties
        var additionalAutoProperties: [String: Any] = [:]

        /// anonymous id generator
        var anonymousIDFactory: () -> String = {
            UIDevice.identifier
        }

        /// Create an UserPilot SDK configuration
        /// - Parameter accountID: UserPilot Account ID - a string containing an integer,
        ///  copied from the Account settings page in Studio.
        /// - Parameter applicationID: UserPilot Application ID - a string containing a UUID,
        ///  copied from the Apps & Installation page in Studio for this iOS application.
        public init(token: String) {
            self.token = token
        }

        /// Set the logging status for the configuration.
        /// - Parameter enabled: Whether logging is enabled.
        /// - Returns: The `Configuration` object.
        ///
        /// Refer to <doc:Logging> for details.
        @discardableResult
        @objc
        public func logging(_ enabled: Bool) -> Self {
            logger = enabled ? OSLog(userpilotCategory: "general") : .disabled
            return self
        }
    }

}
