//
//  Constants.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
// [Brief Description]
// Constants hold sdk constants
//

import Foundation

// swiftlint:disable identifier_name
struct DispatchQueueConstants {
    static let EVENT_QUEUE = "userpilot-event-queue"
    static let DI_CONTAINER_QUEUE = "userpilot-dicontainer"
    static let DEBOUNCER_QUEUE = "userpilot-debouncer-queue"
}

struct EventCaseNameConstants {
    static let IDENTIFY = "identify"
    static let SCREEN = "screen"
    static let EVENT = "event"
}

struct EventNameConstants {
    static let IDENTIFY = "user_identify"
    static let SCREEN = "screen"
    static let EVENT = "event"
}

struct GeneralConstants {
    static let MAX_EVENTS_PER_SCREEN = 200
    static let MAX_ACTION_TO_DEBOUNCE = 20
}
// swiftlint:enable identifier_name
