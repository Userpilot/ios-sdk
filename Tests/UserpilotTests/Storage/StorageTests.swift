//
//  StorageTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class StorageTests: XCTestCase {

    var storage: Storage!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)

        // Use test-specific UserDefaults suite
        UserDefaults().removePersistentDomain(forName: "\(Storage.userDefaultSuiteName)\(Bundle.main.identifier)")
        storage = Storage(container: userpilot.container)
    }

    override func tearDown() {
        // Clean up UserDefaults
        if let defaults = UserDefaults(suiteName: "\(Storage.userDefaultSuiteName)\(Bundle.main.identifier)") {
            for key in defaults.dictionaryRepresentation().keys {
                defaults.removeObject(forKey: key)
            }
        }

        super.tearDown()
    }

    func testSocketURLStorage() {
        storage.socketURL = "wss://socket.example.com"
        XCTAssertEqual(storage.socketURL, "wss://socket.example.com")
    }

    func testUserIdStorage() {
        storage.userId = "user-00000"
        XCTAssertEqual(storage.userId, "user-00000")
    }

    func testUserStorage() {
        storage.user = "{\"userId\":\"user-00000\"}"
        XCTAssertEqual(storage.user, "{\"userId\":\"user-00000\"}")
    }

    func testTemporaryUserStorage() {
        storage.temporaryUser = "user-00000"
        XCTAssertEqual(storage.temporaryUser, "user-00000")

        storage.temporaryUser = nil
        XCTAssertNil(storage.temporaryUser)
    }

    func testSessionDateStorage() {
        let now = Date()
        storage.sessionDate = now

        guard let storedTime = storage.sessionDate?.timeIntervalSince1970 else {
            return XCTFail("Expected sessionDate to be non-nil")
        }

        XCTAssertEqual(storedTime, now.timeIntervalSince1970, accuracy: 0.1)
    }

    func testConfigurationDateStorage() {
        let date = Date()
        storage.configurationDate = date

        guard let storedTime = storage.configurationDate?.timeIntervalSince1970 else {
            return XCTFail("Expected configurationDate to be non-nil")
        }

        XCTAssertEqual(storedTime, date.timeIntervalSince1970, accuracy: 0.1)
    }

    func testPushTokenStorage() {
        storage.pushToken = "token-00000"
        XCTAssertEqual(storage.pushToken, "token-00000")

        storage.pushToken = nil
        XCTAssertNil(storage.pushToken)
    }
}
