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

/// is Debug Mode flag
#if DEBUG
let isDebugMode = true
#else
let isDebugMode = false
#endif

// swiftlint:disable identifier_name
internal struct DispatchQueueConstants {
    static let EVENT_QUEUE = "userpilot-event-queue"
    static let DI_CONTAINER_QUEUE = "userpilot-dicontainer"
    static let THROTTLE_QUEUE = "userpilot-throttle-queue"
}

internal struct GeneralConstants {
    static let SESSION_DURATION = TimeInterval(30 * 60)
    static let CONFIGURATION_DURATION = TimeInterval(30 * 60)
}
// swiftlint:enable identifier_name
