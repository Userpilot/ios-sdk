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

internal enum Constants {
    enum DispatchQueues {
        static let event = "com.userpilot.event-queue"
        static let experience = "com.userpilot.experience-queue"
        static let delay = "com.userpilot.delay-queue"
        static let diContainer = "com.userpilot.dicontainer-queue"
        static let throttle = "com.userpilot.throttle-queue"
        static let database = "com.userpilot.database-queue"
        static let networkMonitor = "com.userpilot.network-monitor-queue"
    }

    enum General {
        static let userpilotLoggingCategory = "general"
    }

    enum Event {
        static let identifyEvent = "user_identify"
        static let screenEvent = "screen"
        static let trackEvent = "track"
        static let batchEventsEvent = "batch_events"
    }

    enum Analytics {
        /** Property key for event metadata */
        static let metaDataProperty = "metadata"

        /** Property key for company information in identify events */
        static let identifyCompanyProperty = "company"

        /** Property key for screen title in screen events */
        static let screenTitleProperty = "title"

        /** Property key indicating if this is the start of a new session */
        static let isSessionStartedProperty = "is_session_start"

        /** Property key for fake reload state */
        static let fakeReload = "fake_reload"

        /** Property key for tracking seen flows/experiences */
        static let seenContents = "seen_contents"

        /** Property key for tracking seen surveys */
        static let seenSurveys = "seen_surveys"

        /** Property key for custom event names */
        static let eventNameProperty = "event_name"

        // Session duration for isStartSession flag which is 30 minutes
        static let sessionDuration = TimeInterval(30 * 60)
    }

    enum OfflineEvents {
        static let eventTypeProperty = "event_type"
        static let createdAtProperty = "created_at"
    }

    enum AutoProperty {
        static let autoPropertiesKey = "autoProperties"
        static let fontsKey = "fontsProperties"
        static let appPropertiesKey = "appProperties"

        // ── Platform ──────────────────────────────────────────────────────────────────
        static let osKey                    = "operating_system"
        static let osVersionKey             = "operating_system_version"
        static let libraryVersionKey        = "library_version"
        static let overlayLibraryVersionKey = "overlay_library_version"
        static let manufacturerKey          = "manufacturer"
        static let sdkTypeKey               = "sdk_type"

        // ── Device ────────────────────────────────────────────────────────────────────
        static let deviceModelKey           = "device_model"
        static let deviceTypeKey            = "device_type"
        static let deviceNameKey            = "device_name"
        static let isiOSOnMacKey            = "is_ios_on_mac"
        static let isSimulatorKey           = "is_simulator"
        static let isJailbrokenKey          = "is_jailbroken"
        static let processorCountKey        = "processor_count"
        static let totalRAMKey              = "total_ram_bytes"
        static let totalDiskSpaceKey        = "total_disk_bytes"
        static let freeDiskSpaceKey         = "free_disk_bytes"

        // ── Screen ────────────────────────────────────────────────────────────────────
        static let screenWidthKey           = "screen_width"
        static let screenHeightKey          = "screen_height"
        static let screenScaleKey           = "screen_scale"

        // ── Locale & Region ───────────────────────────────────────────────────────────
        static let localeKey                = "locale"
        static let languageKey              = "language"
        static let countryCodeKey           = "country_code"
        static let currencyCodeKey          = "currency_code"
        static let countryNameKey           = "country_name"

        // ── Timezone ──────────────────────────────────────────────────────────────────
        static let timezoneKey              = "timezone"
        static let timezoneOffsetMinutesKey = "timezone_offset_minutes"
        static let timezoneOffsetHoursKey   = "timezone_offset_hours"

        // ── Network ───────────────────────────────────────────────────────────────────
        static let carrierNameKey           = "carrier_name"
        static let radioTechnologyKey       = "radio_technology"

        // ── Dynamic / Runtime State ───────────────────────────────────────────────────
        static let isLowPowerModeKey        = "is_low_power_mode"
        static let isDarkModeKey            = "is_dark_mode"

        // ── App ───────────────────────────────────────────────────────────────────────
        static let appNameKey               = "app_name"
        static let appIdentifierKey         = "app_identifier"
        static let appVersionKey            = "app_version"
        static let appBuildKey              = "app_build"
        static let appIsSwiftUIKey          = "app_swift_ui"
    }

    enum Database {
        /// Maximum number of events allowed in storage
        static let maxEventCount = 5_000

        /// Maximum total size in bytes (3 MB)
        static let maxSizeBytes: Int64 = 3 * 1024 * 1024
    }

    enum RemoteSource {
        static let settingsBaseURL = "https://find.userpilot.io/v1/lookups/"
        static let socketPath = "/mobile/v1/events/websocket"
        static let experienceBaseURL =
        "https://appex-dev-nxtapp-14664.userpilot.io/api/v1/public/content"
        static let configurationDuration = TimeInterval(30 * 60)  // 30 minutes
    }

    enum Socket {
        static let channelTopic = "events:*"
        static let successKey = "ok"
        static let errorKey = "error"

        static let tokenKey = "app_token"
        static let userIdKey = "user_id"
        static let autoPropertiesKey = "auto_properties"
        static let appPropertiesKey = "app_properties"
        static let sdkVersionKey = "sdk_version"
    }

    enum Storage {
        static let userDefaultSuiteName = "com.userpilot.storage."
    }
}
