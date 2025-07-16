//
//  PushNotificationMonitorTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 15/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot
@testable import SwiftPhoenixClient

class PushNotificationMonitorTests: XCTestCase {

    var pushNotificationMonitor: PushNotificationMonitor!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        pushNotificationMonitor = PushNotificationMonitor(container: userpilot.container)
    }

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
        var didTrackedFlushEvent = true
        userpilot.analyticsPublisher.onPublish = { _ in didTrackedFlushEvent = true }

        userpilot.storage.pushToken = ""
        let token = Data("token-00000".utf8)

        // Act
        pushNotificationMonitor.setPushToken(token)

        // Assert
        XCTAssertTrue(didTrackedFlushEvent)
    }

    func testOnSocketEventSent_updatesToken_whenUserTokenEventReceived() throws {
        // Act
        pushNotificationMonitor.onSocketEventSent("user_token", ["token": "token-00000"], Message(), true)

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

        var didTrackedFlushEvent = true
        userpilot.analyticsPublisher.onPublish = { _ in didTrackedFlushEvent = true }

        // Act
        pushNotificationMonitor.onSocketOpened()

        // Assert
        XCTAssertTrue(didTrackedFlushEvent)
    }

    // MARK: Receive Handler

    func testDidReceiveNotification_returnsFalse_whenSessionIsActiveWithNonUserpilotNotification() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.basicPush // swiftlint:disable:this syntactic_sugar
        let response = try XCTUnwrap(UNNotificationResponse.mock(userInfo: userInfo))
        userpilot.storage.userId = "default-00000"

        // Act
        let result = pushNotificationMonitor.didReceiveNotification(response: response, completionHandler: {})

        // Assert
        XCTAssertFalse(result)
    }

    func testDidReceiveNotification_returnsTrue_whenUserpilotPushAndUserMatches() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.userpilotPushNotification // swiftlint:disable:this syntactic_sugar
        let response = try XCTUnwrap(UNNotificationResponse.mock(userInfo: userInfo))
        userpilot.storage.userId = "default-00000"

        // Act
        let result = pushNotificationMonitor.didReceiveNotification(response: response, completionHandler: { })

        // Assert
        XCTAssertTrue(result)
    }

    func testDidReceiveNotification_callsCompletion_whenUserpilotPushMatchesUser() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.userpilotPushNotification // swiftlint:disable:this syntactic_sugar
        let response = try XCTUnwrap(UNNotificationResponse.mock(userInfo: userInfo))
        let completionExpectation = expectation(description: "completion called")
        let completion = { completionExpectation.fulfill() }

        userpilot.storage.userId = "default-1111"

        // Act
        let result = pushNotificationMonitor.didReceiveNotification(response: response, completionHandler: completion)

        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(result)
    }

    func testDidReceiveNotification_returnsTrue_whenUserpilotPushButEventRequestsNotAllowed() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.userpilotPushNotification // swiftlint:disable:this syntactic_sugar
        let response = try XCTUnwrap(UNNotificationResponse.mock(userInfo: userInfo))
        let completionExpectation = expectation(description: "completion called")
        let completion = { completionExpectation.fulfill() }

        userpilot.storage.userId = "default-1111"
        userpilot.analyticsPublisher.canRequestEvent = false

        // Act
        let result = pushNotificationMonitor.didReceiveNotification(response: response, completionHandler: completion)

        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(result)
    }

    func testAttemptDeferredNotificationResponse_handlesDeferred_whenUserMatches() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.userpilotPushNotification // swiftlint:disable:this syntactic_sugar
        let response = try XCTUnwrap(UNNotificationResponse.mock(userInfo: userInfo))

        let analyticsExpectation = expectation(description: "push open event")
        let linkCompletionExpectation = expectation(description: "link opened")
        let completionExpectation = expectation(description: "completion called")

        let completion = { completionExpectation.fulfill() }

        userpilot.storage.userId = "default-00000"
        userpilot.analyticsPublisher.canRequestEvent = false

        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { sdkEvent, _, _ in
            // Try casting to your specific event type
            guard let event = sdkEvent as? PushNotificationOpenedEvent else {
                XCTFail("sdkEvent is not PushNotificationOpenedEvent")
                return
            }

            // Access the payload dictionary
            let payload = event.eventPayload

            // Now assert the value for "notification_id"
            guard let notificationId = payload["notification_id"] as? Int else {
                XCTFail("notification_id is missing or not an Int")
                return
            }

            XCTAssertEqual(notificationId, 5)

            analyticsExpectation.fulfill()
        }

        let result = pushNotificationMonitor.didReceiveNotification(response: response, completionHandler: completion)

        let navigationDelegate = MockNavigationDelegate()
        userpilot.navigationDelegate = navigationDelegate
        navigationDelegate.onNavigate = { url in
            XCTAssertEqual(url.absoluteString, "app://some-link")
            linkCompletionExpectation.fulfill()
        }

        // Act
        let didHandleDeferred = pushNotificationMonitor.attemptDeferredNotificationResponse()

        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(result)
        XCTAssertTrue(didHandleDeferred)
    }

    func testAttemptDeferredNotificationResponse_doesNotHandle_whenUserMismatch() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.userpilotPushNotification // swiftlint:disable:this syntactic_sugar
        let response = try XCTUnwrap(UNNotificationResponse.mock(userInfo: userInfo))

        userpilot.storage.userId = "default-11111"
        userpilot.analyticsPublisher.canRequestEvent = false

        let result = pushNotificationMonitor.didReceiveNotification(response: response, completionHandler: {})

        // Act
        let didHandleDeferred = pushNotificationMonitor.attemptDeferredNotificationResponse()

        // Assert
        XCTAssertTrue(result)
        XCTAssertFalse(didHandleDeferred)
    }
}

extension Dictionary where Key == AnyHashable, Value == Any {
    static var basicPush: Self {
        [
            "aps": [
                "alert": [
                    "title": "Hello world",
                    "body": "Notification from app"
                ]
            ]
        ]
    }

    static var userpilotPushNotification: Self {
        [
            "data": [
                "notification_type": "userpilot-notification",
                "notification_id": "5",
                "user_id": "default-00000",
                "deep_link": "app://some-link"

            ]
        ]
    }
}

private extension UNNotificationResponse {
    final class KeyedArchiver: NSKeyedArchiver {
        override func decodeObject(forKey _: String) -> Any { "" }

        deinit {
            // Avoid a console warning
            finishEncoding()
        }
    }

    static func mock(
        userInfo: [AnyHashable: Any],
        actionIdentifier: String = UNNotificationDefaultActionIdentifier
    ) -> UNNotificationResponse? {
        guard let response = UNNotificationResponse(coder: KeyedArchiver(requiringSecureCoding: false)),
              let notification = UNNotification(coder: KeyedArchiver(requiringSecureCoding: false)) else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "",
            content: content,
            trigger: nil
        )
        notification.setValue(request, forKey: "request")

        response.setValue(notification, forKey: "notification")
        response.setValue(actionIdentifier, forKey: "actionIdentifier")

        return response
    }
}
