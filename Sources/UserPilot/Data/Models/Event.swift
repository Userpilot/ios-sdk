//
//  TrackingUpdate.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// TrackingUpdate Event details holder
//

import Foundation
import UIKit

struct Event {

    // MARK: - Properties
    let type: EventType
    var properties: [String: Any]?
    var company: [String: Any]?
    let timestamp = Date()

    var userID: String? {
        return type.userID
    }
}

extension Event {

    func logData(logger: Logging) {
        logger.info("------------ Event ----------\n")
        logger.info("PUBLISHED ANALYTIC EVENT:\n")
        logger.info("Event name: %{public}@\n", type.title)
        logger.info("Event date: %{public}@\n", self.timestamp.fullDateString)
        logger.info("Event properties:\n")

        if let properties = self.properties {
            for (key, value) in properties {
                if let nestedDict = value as? [String: Any] {
                    logger.info("Event key: %{public}@\n", key)
                    for (nestedKey, nestedValue) in nestedDict {
                        logger.info("   %{public}@ -> %{public}@\n", nestedKey, nestedValue as? CVarArg ?? "")
                    }
                } else if value is [Any] {
                    logger.info("%{public}@ -> %{public}@\n", key, value as? CVarArg ?? [])
                } else if value is Int {
                    logger.info("%{public}@ -> %{public}d\n", key, value as? Int ?? -1)
                } else {
                    logger.info("%{public}@ -> %{public}@\n", key, value as? String ?? "")
                }
            }
        }
        logger.info("----------------------\n")
    }

}
