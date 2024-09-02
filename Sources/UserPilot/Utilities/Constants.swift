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
struct UserDefaultConstants {
    static let USER_DEFAULT_SUITE_NAME = "com.userpilot.storage."
}

struct DispatchQueueConstants {
    static let EVENT_QUEUE = "userpilot-event-queue"
    static let DI_CONTAINER_QUEUE = "userpilot-dicontainer"
}

struct SocketConstants {
    /// Socket Params
    static let SOCKET_CHANNEL_TOPIC = "events:*"
    static let SOCKET_SUCCESS_KEY = "ok"
    static let SOCKET_ERROR_KEY = "error"

    // Socket Keys
    static let SOCKET_TOKEN_KEY = "token"
    static let SOCKET_USER_ID_KEY = "user_id"
    static let SOCKET_AUTO_PROPERTIES_KEY = "auto_properties"
    static let SOCKET_APP_PROPERTIES_KEY = "app_properties"
    static let SOCKET_SDK_VERSION_KEY = "sdk_version"
}

struct EventCaseNameConstants {
    static let IDENTIFY = "identify"
    static let SCREEN = "screen"
    static let COMPANY = "company"
    static let EVENT = "event"
}

struct EventNameConstants {
    static let IDENTIFY = "user_identify"
    static let SCREEN = "screen"
    static let COMPANY = "company"
    static let EVENT = "event"
}
// swiftlint:enable identifier_name
