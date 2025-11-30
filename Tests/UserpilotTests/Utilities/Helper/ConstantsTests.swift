//
//  MulticastTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest

@testable import Userpilot

class ConstantsTests: XCTestCase {

    func testDispatchQueueConstants() {
        XCTAssertEqual(Constants.DispatchQueues.event, "com.userpilot.event-queue")
        XCTAssertEqual(Constants.DispatchQueues.experience, "com.userpilot.experience-queue")
        XCTAssertEqual(Constants.DispatchQueues.delay, "com.userpilot.delay-queue")
        XCTAssertEqual(Constants.DispatchQueues.diContainer, "com.userpilot.dicontainer-queue")
        XCTAssertEqual(Constants.DispatchQueues.throttle, "com.userpilot.throttle-queue")
        XCTAssertEqual(Constants.DispatchQueues.database, "com.userpilot.database-queue")
        XCTAssertEqual(
            Constants.DispatchQueues.networkMonitor, "com.userpilot.network-monitor-queue")
    }

    func testGeneralConstants() {
        XCTAssertEqual(Constants.RemoteSource.socketPath, "/mobile/v1/events/websocket")
        XCTAssertEqual(Constants.Analytics.sessionDuration, 1800, accuracy: 0.1)
        XCTAssertEqual(Constants.RemoteSource.configurationDuration, 1800, accuracy: 0.1)
        XCTAssertEqual(Constants.General.userpilotLoggingCategory, "general")
    }

    func testEventConstants() {
        XCTAssertEqual(Constants.Event.identifyEvent, "user_identify")
        XCTAssertEqual(Constants.Event.screenEvent, "screen")
        XCTAssertEqual(Constants.Event.trackEvent, "track")
        XCTAssertEqual(Constants.Event.batchEventsEvent, "batch_events")
    }

    func testAnalyticsConstants() {
        XCTAssertEqual(Constants.Analytics.metaDataProperty, "metadata")
        XCTAssertEqual(Constants.Analytics.identifyCompanyProperty, "company")
        XCTAssertEqual(Constants.Analytics.screenTitleProperty, "title")
        XCTAssertEqual(Constants.Analytics.isSessionStartedProperty, "is_session_start")
        XCTAssertEqual(Constants.Analytics.fakeReload, "fake_reload")
        XCTAssertEqual(Constants.Analytics.seenContents, "seen_contents")
        XCTAssertEqual(Constants.Analytics.seenSurveys, "seen_surveys")
        XCTAssertEqual(Constants.Analytics.eventNameProperty, "event_name")
    }

    func testAutoPropertyConstants() {
        XCTAssertEqual(Constants.AutoProperty.autoPropertiesKey, "autoProperties")
        XCTAssertEqual(Constants.AutoProperty.fontsKey, "fontsProperties")
        XCTAssertEqual(Constants.AutoProperty.appPropertiesKey, "appProperties")
        XCTAssertEqual(Constants.AutoProperty.osKey, "operating_system")
        XCTAssertEqual(Constants.AutoProperty.osVersionKey, "operating_system_version")
        XCTAssertEqual(Constants.AutoProperty.appVersionKey, "app_version")
        XCTAssertEqual(Constants.AutoProperty.deviceTypeKey, "device_type")
        XCTAssertEqual(Constants.AutoProperty.screenWidthKey, "screen_width")
        XCTAssertEqual(Constants.AutoProperty.screenHeightKey, "screen_height")
        XCTAssertEqual(Constants.AutoProperty.appNameKey, "app_name")
        XCTAssertEqual(Constants.AutoProperty.appIdentifierKey, "app_identifier")
    }

    func testDatabaseConstants() {
        XCTAssertEqual(Constants.Database.maxEventCount, 10_000)
        XCTAssertEqual(Constants.Database.maxSizeBytes, 5 * 1024 * 1024)
    }

    func testOfflineEventsConstants() {
        XCTAssertEqual(Constants.OfflineEvents.eventTypeProperty, "event_type")
        XCTAssertEqual(Constants.OfflineEvents.createdAtProperty, "created_at")
    }

    func testRemoteSourceConstants() {
        XCTAssertEqual(
            Constants.RemoteSource.settingsBaseURL, "https://find.userpilot.io/v1/lookups/")
        XCTAssertEqual(Constants.RemoteSource.socketPath, "/mobile/v1/events/websocket")
        XCTAssertEqual(
            Constants.RemoteSource.experienceBaseURL,
            "https://appex-dev-nxtapp-14664.userpilot.io/api/v1/public/content")
        XCTAssertEqual(Constants.RemoteSource.configurationDuration, 1800, accuracy: 0.1)
    }
}
