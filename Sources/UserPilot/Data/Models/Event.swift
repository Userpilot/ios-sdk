//
//  TrackingUpdate.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `Event` struct is a holder for event details in the UserPilot SDK.
//  It tracks information about various user actions, analytics events, and their associated metadata.
//

import Foundation
import UIKit

/// `Event` represents a user interaction or analytics event in the UserPilot SDK.
/// It captures essential details such as the event type, optional properties, company details, and the timestamp.
internal struct Event {

    // MARK: - Properties

    /// The type of event, described by the `EventType` enum.
    /// This determines the nature of the event (e.g., screen view, custom action).
    let type: EventType

    /// A dictionary of optional properties that provide additional
    /// metadata for the event (e.g., button clicked, item purchased).
    var properties: [String: Any]?

    /// A dictionary of optional company-related properties. This can be
    /// used to track events related to specific organizations or entities.
    var company: [String: Any]?

    let userID: String
    
    /// The timestamp when the event was created, captured at the moment
    /// of event initialization. Defaults to the current date and time.
    let timestamp = Date()
}

// MARK: - Event Logging

internal extension Event {

    /**
     Logs the details of the event using a provided logger instance.
     
     This method formats the event data and outputs the information, including
     the event type, timestamp, and associated properties,
     using the `Logging` protocol. It handles nested dictionaries and
     arrays, formatting them appropriately for easier readability.
     
     - Parameter logger: An instance conforming to the `Logging` protocol, responsible for outputting logs.
     */
    internal func logData(logger: Logging) {
        // Log the event header
        logger.info("------------ Event ----------\n")
        logger.info("PUBLISHED ANALYTIC EVENT:\n")

        // Log the event type (e.g., screen view, user interaction)
        logger.info("Event name: %{public}@\n", type.title)

        // Log the event timestamp (formatted as a full date string)
        logger.info("Event date: %{public}@\n", self.timestamp.fullDateString)

        // Log any properties associated with the event
        logger.info("Event properties:\n")

        // Check if properties exist, then iterate through them
        if let properties = self.properties {
            for (key, value) in properties {
                if let nestedDict = value as? [String: Any] {
                    logger.info("Event key: %{public}@\n", key)

                    // Handle nested dictionaries and log their keys/values
                    for (nestedKey, nestedValue) in nestedDict {
                        logger.info("   %{public}@ -> %{public}@\n", nestedKey, nestedValue as? CVarArg ?? "")
                    }
                } else if let arrayValue = value as? [Any] {
                    // Handle arrays by logging their content
                    logger.info("%{public}@ -> %{public}@\n", key, arrayValue)
                } else if let intValue = value as? Int {
                    // Handle integers and log them
                    logger.info("%{public}@ -> %{public}d\n", key, intValue)
                } else {
                    // Log any other property as a string
                    logger.info("%{public}@ -> %{public}@\n", key, value as? String ?? "")
                }
            }
        }
        // Log event footer to signal the end of the log
        logger.info("----------------------\n")
    }

}
