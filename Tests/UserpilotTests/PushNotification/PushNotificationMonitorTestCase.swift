//
//  PushNotificationMonitorTestCase.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

class PushNotificationMonitorTestCase: XCTestCase {

    var pushNotificationMonitor: PushNotificationMonitor!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        Userpilot.Registry.shared.resetForTesting()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        userpilot = MockUserpilot(config: config)
        pushNotificationMonitor = PushNotificationMonitor(container: userpilot.container)
    }

    override func tearDownWithError() throws {
        pushNotificationMonitor = nil
        userpilot = nil
        Userpilot.Registry.shared.resetForTesting()
        try super.tearDownWithError()
    }

    func userpilotPushNotification(
        userId: String = "default-00000",
        notificationId: Any = "5"
    ) -> [AnyHashable: Any] {
        .userpilotPushNotification(
            appToken: userpilot.config.token,
            userId: userId,
            notificationId: notificationId
        )
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

    static func userpilotPushNotification(
        appToken: String? = "NX-00000",
        userId: String = "default-00000",
        notificationId: Any = "5"
    ) -> Self {
        var data: [String: Any] = [
            "notification_type": "userpilot-notification",
            "notification_id": notificationId,
            "user_id": userId,
            "deep_link": "app://some-link"
        ]

        if let appToken {
            data["app_token"] = appToken
        }

        return [
            "data": data
        ]
    }

    static var userpilotPushNotification: Self {
        userpilotPushNotification()
    }
}

private extension UNNotificationResponse {
    final class KeyedArchiver: NSKeyedArchiver {
        override func decodeObject(forKey _: String) -> Any { "" }

        deinit {
            // Avoid a console warning.
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
