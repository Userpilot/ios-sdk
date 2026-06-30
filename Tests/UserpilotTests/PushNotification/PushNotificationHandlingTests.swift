//
//  PushNotificationHandlingTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class PushNotificationHandlingTests: PushNotificationMonitorTestCase {

    func testDidReceiveNotification_returnsFalse_whenSessionIsActiveWithNonUserpilotNotification() throws {
        // Arrange
        let userInfo = Dictionary<AnyHashable, Any>.basicPush // swiftlint:disable:this syntactic_sugar
        userpilot.storage.userId = "default-00000"

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(userInfo: userInfo)

        // Assert
        XCTAssertFalse(result)
    }

    func testDidReceiveNotification_returnsTrue_whenUserpilotPushAndUserMatches() throws {
        // Arrange
        let userInfo = userpilotPushNotification()
        userpilot.storage.userId = "default-00000"

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(userInfo: userInfo)

        // Assert
        XCTAssertTrue(result)
    }

    func testDidReceiveNotification_callsCompletion_whenUserpilotPushMatchesUser() throws {
        // Arrange
        let userInfo = userpilotPushNotification()
        let completionExpectation = expectation(description: "completion called")
        let completion = { completionExpectation.fulfill() }

        userpilot.storage.userId = "default-00000"

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(
            userInfo: userInfo,
            completionHandler: completion
        )

        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(result)
    }

    func testDidReceiveNotification_returnsTrue_whenUserpilotPushButEventRequestsNotAllowed() throws {
        // Arrange
        let userInfo = userpilotPushNotification()
        let completionExpectation = expectation(description: "completion called")
        let completion = { completionExpectation.fulfill() }

        userpilot.storage.userId = "default-00000"
        userpilot.analyticsPublisher.canRequestEvent = false

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(
            userInfo: userInfo,
            completionHandler: completion
        )

        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(result)
    }

    func testDidReceiveNotification_returnsFalse_whenAppTokenMismatch() throws {
        // Arrange
        let userInfo = [AnyHashable: Any].userpilotPushNotification(appToken: "NX-11111")
        userpilot.storage.userId = "default-00000"

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(userInfo: userInfo)

        // Assert
        XCTAssertFalse(result)
    }

    func testDidReceiveNotification_routesToMatchingInstanceWhenMultipleInstancesExist() throws {
        // Arrange
        Userpilot.Registry.shared.resetForTesting()
        let host = MockUserpilot(config: Userpilot.Config(token: "HOST-PUSH"))
        let vendor = MockUserpilot(config: Userpilot.Config(token: "VENDOR-PUSH").defaultInstance(false))
        let hostMonitor = PushNotificationMonitor(container: host.container)
        let vendorMonitor = PushNotificationMonitor(container: vendor.container)

        host.storage.userId = "host-user"
        vendor.storage.userId = "vendor-user"

        var hostEvents: [SDKEvent] = []
        var vendorEvents: [SDKEvent] = []
        var hostCompletionCalled = false
        var vendorCompletionCalled = false
        var navigatedURL: URL?

        host.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in hostEvents.append(event) }
        vendor.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in vendorEvents.append(event) }

        vendor.linkOpener.onHandleURL = { url in navigatedURL = url }

        let userInfo = [AnyHashable: Any].userpilotPushNotification(
            appToken: vendor.config.token,
            userId: "vendor-user",
            notificationId: "42"
        )

        // Act
        let hostResult = hostMonitor.processNotificationForTesting(
            userInfo: userInfo,
            completionHandler: { hostCompletionCalled = true }
        )
        let vendorResult = vendorMonitor.processNotificationForTesting(
            userInfo: userInfo,
            completionHandler: { vendorCompletionCalled = true }
        )

        // Assert
        XCTAssertFalse(hostResult)
        XCTAssertTrue(vendorResult)
        XCTAssertFalse(hostCompletionCalled)
        XCTAssertTrue(vendorCompletionCalled)
        XCTAssertTrue(hostEvents.isEmpty)
        XCTAssertEqual(vendorEvents.count, 1)
        XCTAssertEqual(vendorEvents.first?.eventName, SDKEventsName.pushNotificationOpened.rawValue)
        XCTAssertEqual(vendorEvents.first?.eventPayload["notification_id"] as? Int, 42)
        XCTAssertEqual(navigatedURL?.absoluteString, "app://some-link")

        _ = host
        _ = vendor
        _ = hostMonitor
        _ = vendorMonitor
    }

    func testDidReceiveNotification_rejectsMatchingAppTokenWhenUserBelongsToAnotherInstance() throws {
        // Arrange
        let userInfo = [AnyHashable: Any].userpilotPushNotification(
            appToken: userpilot.config.token,
            userId: "other-user"
        )
        userpilot.storage.userId = "current-user"

        var didPublishEvent = false
        var didCallCompletion = false
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { _, _ in didPublishEvent = true }

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(
            userInfo: userInfo,
            completionHandler: { didCallCompletion = true }
        )

        // Assert
        XCTAssertFalse(result)
        XCTAssertFalse(didPublishEvent)
        XCTAssertFalse(didCallCompletion)
    }

    func testDidReceiveNotification_handlesLegacyPayloadWithoutAppTokenWhenUserMatches() throws {
        // Arrange
        let userInfo = [AnyHashable: Any].userpilotPushNotification(
            appToken: nil,
            userId: "default-00000",
            notificationId: "9"
        )
        userpilot.storage.userId = "default-00000"

        var publishedEvent: SDKEvent?
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            publishedEvent = event
        }

        // Act
        let result = pushNotificationMonitor.processNotificationForTesting(userInfo: userInfo)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(publishedEvent?.eventName, SDKEventsName.pushNotificationOpened.rawValue)
        XCTAssertEqual(publishedEvent?.eventPayload["notification_id"] as? Int, 9)
    }
}
