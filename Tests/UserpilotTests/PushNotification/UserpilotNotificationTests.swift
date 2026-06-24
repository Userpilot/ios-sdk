//
//  UserpilotNotificationTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class UserpilotNotificationTests: XCTestCase {

    func testValidPayloadParsesNotification() throws {
        let notification = try XCTUnwrap(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": "experience",
                "notification_id": "notification-1",
                "app_token": "app-token",
                "user_id": "user-1",
                "deep_link": "https://example.com/path"
            ]
        ]))

        XCTAssertEqual(notification.notificationType, "experience")
        XCTAssertEqual(notification.notificationId, "notification-1")
        XCTAssertEqual(notification.appToken, "app-token")
        XCTAssertEqual(notification.userId, "user-1")
        XCTAssertEqual(notification.deeplink?.absoluteString, "https://example.com/path")
    }

    func testOptionalAppTokenAndInvalidDeepLinkAreAllowed() throws {
        let notification = try XCTUnwrap(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": "experience",
                "notification_id": "notification-1",
                "user_id": "user-1",
                "deep_link": "not a url"
            ]
        ]))

        XCTAssertNil(notification.appToken)
        XCTAssertNotNil(notification.deeplink)
    }

    func testMissingRequiredFieldsReturnNil() {
        let validData: [String: Any] = [
            "notification_type": "experience",
            "notification_id": "notification-1",
            "user_id": "user-1"
        ]

        XCTAssertNil(UserpilotNotification(userInfo: [:]))
        XCTAssertNil(UserpilotNotification(userInfo: ["data": validData.removing("notification_type")]))
        XCTAssertNil(UserpilotNotification(userInfo: ["data": validData.removing("notification_id")]))
        XCTAssertNil(UserpilotNotification(userInfo: ["data": validData.removing("user_id")]))
    }

    func testCustomSchemeDeepLinkParses() throws {
        let notification = try XCTUnwrap(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": "experience",
                "notification_id": "notification-1",
                "user_id": "user-1",
                "deep_link": "userpilot-sample://experience/123"
            ]
        ]))

        XCTAssertEqual(notification.deeplink?.scheme, "userpilot-sample")
        XCTAssertEqual(notification.deeplink?.host, "experience")
    }

    func testEmptyRequiredStringsStillParseWhenKeysArePresent() throws {
        let notification = try XCTUnwrap(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": "",
                "notification_id": "",
                "user_id": ""
            ]
        ]))

        XCTAssertEqual(notification.notificationType, "")
        XCTAssertEqual(notification.notificationId, "")
        XCTAssertEqual(notification.userId, "")
    }

    func testNonStringRequiredFieldsReturnNil() {
        XCTAssertNil(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": 1,
                "notification_id": "notification-1",
                "user_id": "user-1"
            ]
        ]))
        XCTAssertNil(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": "experience",
                "notification_id": 1,
                "user_id": "user-1"
            ]
        ]))
        XCTAssertNil(UserpilotNotification(userInfo: [
            "data": [
                "notification_type": "experience",
                "notification_id": "notification-1",
                "user_id": 1
            ]
        ]))
    }

    func testNonDictionaryDataReturnsNil() {
        XCTAssertNil(UserpilotNotification(userInfo: ["data": "not-a-dictionary"]))
        XCTAssertNil(UserpilotNotification(userInfo: ["data": NSNull()]))
    }
}

private extension Dictionary where Key == String, Value == Any {
    func removing(_ key: String) -> [String: Any] {
        var copy = self
        copy.removeValue(forKey: key)
        return copy
    }
}
