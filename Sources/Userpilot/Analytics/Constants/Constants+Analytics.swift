//
//  Constants+Analytics.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Wire event names, analytics payload keys and offline batch keys.
//

import Foundation

extension Constants {

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
        static let localeCodeProperty = "locale_code"
        static let screenTitleProperty = "title"
        static let isSessionStartedProperty = "is_session_start"
        static let fakeReload = "fake_reload"
        static let seenContents = "seen_contents"
        static let seenSurveys = "seen_surveys"
        static let eventNameProperty = "event_name"
        static let screenProperty = "screen"

        /// Session gap after which a new session starts.
        static let sessionDuration = TimeInterval(30 * 60)
    }

    /// Offline batch event payload keys (wire format).
    enum OfflineEvents {
        static let eventTypeProperty = "event_type"
        static let createdAtProperty = "created_at"
        static let eventsProperty = "events"
    }
}
