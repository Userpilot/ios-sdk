//
//  PushNotificationMonitorTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 15/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class PushNotificationMonitorTests: PushNotificationMonitorTestCase {

    func testPushEnabled_isFalse_whenNoTokenAndNotAuthorized() throws {
        // Arrange
        userpilot.storage.pushToken = nil
        pushNotificationMonitor.mockPushStatus(.denied)

        // Assert
        XCTAssertFalse(pushNotificationMonitor.pushEnabled)
    }

    func testPushEnabled_isFalse_whenNoTokenAndAuthorized() throws {
        // Arrange
        userpilot.storage.pushToken = nil
        pushNotificationMonitor.mockPushStatus(.authorized)

        // Assert
        XCTAssertFalse(pushNotificationMonitor.pushEnabled)
    }

    func testPushEnabled_isFalse_whenTokenExistsButNotAuthorized() throws {
        // Arrange
        userpilot.storage.pushToken = "<token-00000>"
        pushNotificationMonitor.mockPushStatus(.denied)

        // Assert
        XCTAssertFalse(pushNotificationMonitor.pushEnabled)
    }

    func testPushEnabled_isTrue_whenTokenExistsAndAuthorized() throws {
        // Arrange
        userpilot.storage.pushToken = "<token-00000>"
        pushNotificationMonitor.mockPushStatus(.authorized)

        // Assert
        XCTAssertTrue(pushNotificationMonitor.pushEnabled)
    }

    // MARK: Set Token

    func testSetPushToken_doesNotTrack_whenTokenIsSameAsStored() throws {
        // Arrange
        var didTrackedFlushEvent = false
        userpilot.analyticsPublisher.onPublish = { _ in didTrackedFlushEvent = true }

        userpilot.storage.pushToken = Data("token-00000".utf8).map({ String(format: "%02x", $0) }).joined()
        let token = Data("token-00000".utf8)

        // Act
        pushNotificationMonitor.setPushToken(token)

        // Assert
        XCTAssertFalse(didTrackedFlushEvent)
    }

    func testSetPushToken_tracksEvent_whenNewValidTokenIsSet() throws {
        // Arrange
        var publishedEvent: SDKEvent?
        userpilot.storage.pushToken = ""
        userpilot.storage.userId = "user-00000"
        let token = Data("token-00000".utf8)
        let expectedToken = token.map({ String(format: "%02x", $0) }).joined()

        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event in
            publishedEvent = event
        }

        // Act
        pushNotificationMonitor.setPushToken(token)

        // Assert
        let tokenEvent = try XCTUnwrap(publishedEvent as? PushNotificationTokenEvent)
        XCTAssertEqual(tokenEvent.eventName, SDKEventsName.pushNotificationToken.rawValue)
        XCTAssertEqual(tokenEvent.eventPayload["app_token"] as? String, userpilot.config.token)
        XCTAssertEqual(tokenEvent.eventPayload["user_id"] as? String, "user-00000")
        XCTAssertEqual(tokenEvent.eventPayload["token"] as? String, expectedToken)
    }

    func testOnSocketEventSent_updatesToken_whenUserTokenEventReceived() throws {
        // Act
        pushNotificationMonitor.onSocketEventSent(
            SDKEventsName.pushNotificationToken.rawValue,
            ["token": "token-00000"],
            Message(),
            true
        )

        // Assert
        XCTAssertEqual(userpilot.storage.pushToken, "token-00000")
    }

    func testOnSocketEventSent_doesNotUpdateToken_whenNonTokenEventReceived() throws {
        // Act
        pushNotificationMonitor.onSocketEventSent("screen", ["title": "Profile"], Message(), true)

        // Assert
        XCTAssertEqual(userpilot.storage.pushToken, "")
    }

    func testOnSocketOpened_tracksCachedToken_ifAvailable() throws {
        pushNotificationMonitor.setCachedToken(token: Data("token-00000".utf8))

        var publishedEvent: SDKEvent?
        userpilot.storage.userId = "user-00000"
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event in
            publishedEvent = event
        }

        // Act
        pushNotificationMonitor.onSocketOpened()

        // Assert
        let tokenEvent = try XCTUnwrap(publishedEvent as? PushNotificationTokenEvent)
        XCTAssertEqual(tokenEvent.eventPayload["app_token"] as? String, userpilot.config.token)
        XCTAssertEqual(tokenEvent.eventPayload["user_id"] as? String, "user-00000")
        XCTAssertEqual(
            tokenEvent.eventPayload["token"] as? String,
            Data("token-00000".utf8).map({ String(format: "%02x", $0) }).joined()
        )
    }
}
