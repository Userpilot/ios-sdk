//
//  Constants.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Shared infrastructure constants and the public analytics payload alias.
//

import Foundation

/// Optional dictionary passed to analytics events.
public typealias Payload = [String: Any]?

/**
 Namespaced SDK constants.

 Case-less enums are used as namespaces: they cannot be instantiated, carry no state,
 and group related constants under a single discoverable root (`Constants.`).

 Rules:
 - Only general values shared across features live here, such as dispatch queue labels.
 - Feature wire keys, limits, endpoints and timeouts belong in feature-owned `Constants` extensions.
 - Single-consumer implementation details stay as `private static let` on the owning
   type (e.g. `ThemeHandler`, `AutoPropertyDecorator`).
 - Wrapper configuration keys belong in `WrapperSDKConstants`.
 */
internal enum Constants {

    /// Dispatch queue labels.
    enum DispatchQueues {
        static let database = "com.userpilot.database-queue"
        static let networkMonitor = "com.userpilot.network-monitor-queue"
        static let networkMonitorState = "com.userpilot.network-monitor-state-queue"
        static let offlineEvents = "com.userpilot.offline-events-queue"
        static let background = "com.userpilot.background-queue"
        static let eventQueue = "com.userpilot.event-queue"
        static let experienceQueue = "com.userpilot.experience-queue"
        static let screenSessionState = "com.userpilot.screen-session-state-queue"
        static let delayQueue = "com.userpilot.delay-queue"
        static let throttleQueue = "com.userpilot.throttle-queue"
        static let debounceQueue = "com.userpilot.debounce-queue"
        static let registryQueue = "com.userpilot.registry-queue"
    }
}
