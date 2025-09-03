//
//  Constants.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// Constants hold sdk constants
//

import Foundation

/// dictionary typealias
public typealias Payload = [String: Any]?

// swiftlint:disable identifier_name
internal struct DispatchQueueConstants {
    static let EVENT_QUEUE = "com.userpilot.event-queue"
    static let EXPERIENCE_QUEUE = "com.userpilot.experience-queue"
    static let DELAY_QUEUE = "com.userpilot.delay-queue"
    static let DI_CONTAINER_QUEUE = "com.userpilot.dicontainer-queue"
    static let THROTTLE_QUEUE = "com.userpilot.throttle-queue"
}

internal struct GeneralConstants {
    static let PATH_NAME = "/mobile/v1/events/websocket"
    static let SESSION_DURATION = TimeInterval(30 * 60)
    static let CONFIGURATION_DURATION = TimeInterval(30 * 60)
    static let USERPILOT_LOGGING_CATEOGRY = "general"
}
// swiftlint:enable identifier_name
