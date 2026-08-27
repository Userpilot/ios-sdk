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

/**
 Namespaced SDK constants.

 Case-less enums are used as namespaces: they cannot be instantiated, carry no state,
 and group related constants under a single discoverable root (`Constants.`).

 Rules:
 - Wire-format strings (socket event names, payload keys, DB columns), cross-cutting
   tuning values, and anything with two or more consumers live here.
 - Single-consumer implementation details stay as `private static let` on the owning
   type (e.g. `ThemeHandler`, `AutoPropertyDecorator`).
 - Large domains get their own file via `extension Constants`
   (see `Constants+AutoCapture.swift`).
 */
internal enum Constants {

    /// Socket analytics event names (wire format).
    enum Event {
        static let identifyEvent = "user_identify"
        static let screenEvent = "screen"
        static let trackEvent = "track"
        static let autoCaptureEvent = "mobile_autocapture"
        static let batchEventsEvent = "batch_events"
    }

    /// Analytics payload keys and tuning values (wire format unless noted).
    enum Analytics {
        static let metaDataProperty = "metadata"
        static let identifyCompanyProperty = "company"
        static let screenTitleProperty = "title"
        static let isSessionStartedProperty = "is_session_start"
        static let fakeReload = "fake_reload"
        static let seenContents = "seen_contents"
        static let seenSurveys = "seen_surveys"
        static let eventNameProperty = "event_name"
        static let screenProperty = "screen"

        /// Session gap after which a new session starts.
        static let sessionDuration = TimeInterval(30 * 60)

        /// Watchdog for a stuck event-processing cycle. Must stay ABOVE the socket
        /// push timeout so socket ok/error/timeout callbacks always resolve the
        /// in-flight event first; the watchdog only fires when NO callback arrived.
        static let stuckProcessingWatchdog: TimeInterval = Constants.Socket.pushTimeout + 2.0
    }

    /// Offline batch event payload keys (wire format).
    enum OfflineEvents {
        static let eventTypeProperty = "event_type"
        static let createdAtProperty = "created_at"
        static let eventsProperty = "events"
    }

    /// Socket transport keys and timeouts (wire format unless noted).
    enum Socket {
        static let successKey = "ok"
        static let errorKey = "error"
        static let timeoutKey = "timeout"

        static let channelTopic = "events:*"
        static let tokenKey = "app_token"
        static let userIdKey = "user_id"
        static let autoPropertiesKey = "auto_properties"
        static let appPropertiesKey = "app_properties"
        static let sdkVersionKey = "sdk_version"

        /// Phoenix push timeout (matches vendored `Defaults.timeoutInterval`).
        static let pushTimeout: TimeInterval = 10.0
    }

    /// Local offline event database limits and schema.
    enum Database {
        static let maxEventCount = 5_000
        static let maxSizeBytes: Int64 = 3 * 1024 * 1024
        /// Bump when the Events table schema changes; add migration in `EventDatabaseStorage`.
        static let schemaVersion: Int32 = 1
    }

    /// Dispatch queue labels.
    enum DispatchQueues {
        static let database = "com.userpilot.database-queue"
        static let networkMonitor = "com.userpilot.network-monitor-queue"
        static let networkMonitorState = "com.userpilot.network-monitor-state-queue"
        static let offlineEvents = "com.userpilot.offline-events-queue"
        static let background = "com.userpilot.background-queue"
        static let analyticsWatchdog = "com.userpilot.analytics-watchdog-queue"
        static let eventQueue = "com.userpilot.event-queue"
        static let experienceQueue = "com.userpilot.experience-queue"
        static let delayQueue = "com.userpilot.delay-queue"
        static let diContainerQueue = "com.userpilot.dicontainer-queue"
        static let throttleQueue = "com.userpilot.throttle-queue"
        static let debounceQueue = "com.userpilot.debounce-queue"
        static let registryQueue = "com.userpilot.registry-queue"
    }

    /// Network reachability configuration.
    enum Network {
        /// First-party host used for active reachability validation.
        /// Never probe public hosts (Google/Apple/Cloudflare) from customer apps.
        static let reachabilityHost = "find.userpilot.io"
    }

    /// Remote endpoints and settings-cache tuning.
    enum RemoteSource {
        static let settingsBaseURL = "https://find.userpilot.io/v1/lookups/"
        static let socketPath = "/mobile/v1/events/websocket"
        static let experienceBaseURL =
            "https://appex-dev-nxtapp-14664.userpilot.io/api/v1/public/content"
        /// How long fetched SDK settings stay fresh before a refetch.
        static let configurationDuration = TimeInterval(30 * 60)
    }
}

/// Keys used by wrapper SDKs (React Native, Flutter, Ionic) in `additionalProperties`.
internal struct WrapperSDKConstants {
    static let pluginType = "PluginType"
    static let pluginTypeReactNative = "ReactNative"
    static let pluginTypeFlutter = "Flutter"
    static let pluginTypeIonic = "Ionic"
    static let pluginTypeCordova = "Cordova"
    static let pluginTypeMAUI = "MAUI"
    static let enableScreenAutoCapture = "WrapperEnableScreenAutoCapture"
    static let enableInteractionAutoCapture = "WrapperEnableInteractionAutoCapture"
}
