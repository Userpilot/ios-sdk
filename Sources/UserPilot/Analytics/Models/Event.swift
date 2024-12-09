//
//  TrackingUpdate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `Event` struct is a holder for event details in the Userpilot SDK.
//  It tracks information about various user actions, analytics events, and their associated metadata.
//

import Foundation
import UIKit

internal struct Event {

    // MARK: - Properties

    /// The type of event, described by the `EventType` enum.
    /// This determines the nature of the event (e.g., screen view, custom action).
    let type: EventType

    /// A dictionary of optional properties that provide additional
    /// metadata for the event (e.g., button clicked, item purchased).
    var properties: Payload = nil

    /// A dictionary of optional company-related properties. This can be
    /// used to track events related to specific organizations or entities.
    var company: Payload = nil

    /// The timestamp when the event was created, captured at the moment
    /// of event initialization. Defaults to the current date and time.
    let timestamp = Date()

    // MARK: - Variables from `EventType`

    var caseName: String {
        return type.caseName
    }

    var eventName: String {
        return type.eventName
    }

    var eventTitle: String {
        return type.eventTitle ?? ""
    }

    var isEvent: Bool {
        return type.isEvent
    }

    var isScreenEvent: Bool {
        return type.isScreenEvent
    }

    var isIdentifyEvent: Bool {
        return type.isIdentifyEvent
    }

    var screenTitle: String? {
        return type.screenTitle
    }

    var userID: String? {
        return type.userID
    }

    var userpilotAnalytic: UserpilotAnalytic {
        switch type {
        case .identify:
            return .identify
        case .screen:
            return .screen
        case .event:
            return .event
        }
    }
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
    func logData(logger: Logging) {
        logger.info("------------ Event ----------")
        logger.info("PUBLISHED ANALYTIC EVENT:")
        logger.info("Event name: %{public}@", type.eventName)
        logger.info("Event date: %{public}@", self.timestamp.fullDateString)
        logger.info("Event properties:")
        if let properties, let propertiesJsonString = properties.toJSONString() {
            logger.info("Event properties: %{public}@", propertiesJsonString)
        } else {
            logger.info("No properties")
        }
        logger.info("Event company properties:")
        if let company, let companyJsonString = company.toJSONString() {
            logger.info("Event company: %{public}@", companyJsonString)
        } else {
            logger.info("No company")
        }
        logger.info("----------------------")
    }

}

extension Event {
    func toUser() -> User {
        return User(userID: userID ?? "",
                    properties: properties ?? [:],
                    company: company ?? [:])
    }
}
