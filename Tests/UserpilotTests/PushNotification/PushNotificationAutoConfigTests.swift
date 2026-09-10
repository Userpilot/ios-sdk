//
//  PushNotificationAutoConfigTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

/// A push opened before the SDK is configured.
///
/// Hybrid wrappers call `initialize` from their own runtime, so the tap can be
/// delivered while no instance exists yet — reliably so in a Capacitor app,
/// whose WebView boots long after `didFinishLaunchingWithOptions`.
final class PushNotificationAutoConfigTests: PushNotificationMonitorTestCase {

    func testDidReceive_replaysTheResponse_whenItsInstanceRegistersLater() throws {
        // Arrange: a Userpilot push carrying a token no instance has claimed.
        let lateToken = "NX-\(UUID().uuidString)"
        let response = try XCTUnwrap(
            UNNotificationResponse.mock(
                userInfo: .userpilotPushNotification(appToken: lateToken)
            )
        )
        let completionCalled = expectation(description: "completion handler called")

        // Act: the tap arrives with nothing able to handle it.
        PushNotificationAutoConfig.didReceive(response) { completionCalled.fulfill() }
        wait(for: [completionCalled], timeout: 1.0)

        // The instance comes up afterwards, the way it does when a hybrid app
        // finally calls initialize. Its monitor registers from `init`.
        let lateUserpilot = MockUserpilot(
            config: Userpilot.Config(token: lateToken).defaultInstance(false)
        )
        lateUserpilot.storage.userId = "default-00000"
        lateUserpilot.analyticsPublisher.canRequestEvent = false
        let lateMonitor = PushNotificationMonitor(container: lateUserpilot.container)

        let linkOpened = expectation(description: "deep link opened")
        lateUserpilot.linkOpener.onHandleURL = { url in
            XCTAssertEqual(url.absoluteString, "app://some-link")
            linkOpened.fulfill()
        }

        // Assert: the response was held for that instance, not dropped.
        XCTAssertTrue(lateMonitor.attemptDeferredNotificationResponse())
        wait(for: [linkOpened], timeout: 1.0)
    }

    func testDidReceive_routesToTheLiveInstance_whenOneIsAlreadyRegistered() throws {
        // The monitor built by the test case registered itself on init, so this
        // is the warm path: it must still be answered directly, not cached.
        let response = try XCTUnwrap(
            UNNotificationResponse.mock(userInfo: userpilotPushNotification())
        )
        userpilot.storage.userId = "default-00000"
        userpilot.analyticsPublisher.canRequestEvent = false

        PushNotificationAutoConfig.didReceive(response) {}

        XCTAssertTrue(pushNotificationMonitor.attemptDeferredNotificationResponse())
    }
}
