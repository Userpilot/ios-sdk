//
//  PushNotificationDeferredTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class PushNotificationDeferredTests: PushNotificationMonitorTestCase {

    func testAttemptDeferredNotificationResponse_handlesDeferred_whenUserMatches() throws {
        // Arrange
        let userInfo = userpilotPushNotification()

        let analyticsExpectation = expectation(description: "push open event")
        let linkCompletionExpectation = expectation(description: "link opened")
        let completionExpectation = expectation(description: "completion called")

        let completion = { completionExpectation.fulfill() }

        userpilot.storage.userId = "default-00000"
        userpilot.analyticsPublisher.canRequestEvent = false

        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { sdkEvent, _ in
            guard let event = sdkEvent as? PushNotificationOpenedEvent else {
                XCTFail("sdkEvent is not PushNotificationOpenedEvent")
                return
            }

            guard let notificationId = event.eventPayload["notification_id"] as? Int else {
                XCTFail("notification_id is missing or not an Int")
                return
            }

            XCTAssertEqual(notificationId, 5)

            analyticsExpectation.fulfill()
        }

        let result = pushNotificationMonitor.processNotificationForTesting(
            userInfo: userInfo,
            completionHandler: completion
        )

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
        let userInfo = userpilotPushNotification()

        userpilot.storage.userId = "default-11111"
        userpilot.analyticsPublisher.canRequestEvent = false

        let result = pushNotificationMonitor.processNotificationForTesting(userInfo: userInfo)

        // Act
        let didHandleDeferred = pushNotificationMonitor.attemptDeferredNotificationResponse()

        // Assert
        XCTAssertFalse(result)
        XCTAssertFalse(didHandleDeferred)
    }
}
