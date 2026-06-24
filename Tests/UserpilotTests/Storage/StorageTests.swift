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
    var token: String!

    override func setUpWithError() throws {
        super.setUp()
        token = "NX-\(UUID().uuidString)"
        clearStorageSuite(forToken: token)
        storage = makeStorage(token: token)
    }

    override func tearDown() {
        clearStorageSuite(forToken: token)
        storage = nil
        token = nil
        super.tearDown()
    }

    func testSuiteNamesIncludeBundleIdentifierAndToken() {
        XCTAssertEqual(
            Storage.legacyUserDefaultSuiteName,
            "\(Storage.userDefaultSuiteName)\(Bundle.main.identifier)"
        )
        XCTAssertEqual(
            Storage.suiteName(forToken: token),
            "\(Storage.userDefaultSuiteName)\(Bundle.main.identifier).\(token!)"
        )
        XCTAssertEqual(Storage.legacySystemSuiteName, "\(Storage.userDefaultSuiteName)__system")
    }

    func testDefaultValuesBeforeWrites() {
        XCTAssertEqual(storage.socketURL, "")
        XCTAssertEqual(storage.userId, "")
        XCTAssertEqual(storage.anonymousUserId, "")
        XCTAssertNil(storage.temporaryUser)
        XCTAssertNil(storage.sessionDate)
        XCTAssertNil(storage.configurationDate)
        XCTAssertNil(storage.pushToken)
        XCTAssertEqual(User.fromJson(storage.user).userId, "")
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

    func testValuesPersistAcrossStorageInstancesForSameToken() {
        storage.socketURL = "wss://socket.example.com"
        storage.userId = "user-00000"
        storage.anonymousUserId = "anonymous-00000"
        storage.user = "{\"userId\":\"user-00000\"}"
        storage.temporaryUser = "identify-payload"
        storage.configurationDate = Date(timeIntervalSince1970: 1_700_000_000)
        storage.pushToken = "push-token"

        let reloadedStorage = makeStorage(token: token)

        XCTAssertEqual(reloadedStorage.socketURL, "wss://socket.example.com")
        XCTAssertEqual(reloadedStorage.userId, "user-00000")
        XCTAssertEqual(reloadedStorage.anonymousUserId, "anonymous-00000")
        XCTAssertEqual(reloadedStorage.user, "{\"userId\":\"user-00000\"}")
        XCTAssertEqual(reloadedStorage.temporaryUser, "identify-payload")
        guard let configurationTime = reloadedStorage.configurationDate?.timeIntervalSince1970 else {
            return XCTFail("Expected configurationDate to persist")
        }
        XCTAssertEqual(configurationTime, 1_700_000_000, accuracy: 0.1)
        XCTAssertEqual(reloadedStorage.pushToken, "push-token")
    }

    func testStorageSuitesAreIsolatedByToken() {
        let otherToken = "NX-\(UUID().uuidString)"
        clearStorageSuite(forToken: otherToken)
        defer { clearStorageSuite(forToken: otherToken) }

        storage.userId = "primary-user"
        storage.pushToken = "primary-push-token"

        let otherStorage = makeStorage(token: otherToken)
        otherStorage.userId = "other-user"
        otherStorage.pushToken = "other-push-token"

        XCTAssertEqual(storage.userId, "primary-user")
        XCTAssertEqual(storage.pushToken, "primary-push-token")
        XCTAssertEqual(otherStorage.userId, "other-user")
        XCTAssertEqual(otherStorage.pushToken, "other-push-token")
    }

    func testRemovingOptionalValuesDoesNotAffectRequiredStringValues() {
        storage.userId = "user-00000"
        storage.temporaryUser = "temporary"
        storage.sessionDate = Date(timeIntervalSince1970: 100)
        storage.configurationDate = Date(timeIntervalSince1970: 200)
        storage.pushToken = "push-token"

        storage.temporaryUser = nil
        storage.sessionDate = nil
        storage.configurationDate = nil
        storage.pushToken = nil

        XCTAssertEqual(storage.userId, "user-00000")
        XCTAssertNil(storage.temporaryUser)
        XCTAssertNil(storage.sessionDate)
        XCTAssertNil(storage.configurationDate)
        XCTAssertNil(storage.pushToken)
    }

    private func makeStorage(token: String) -> Storage {
        let container = DIContainer()
        let config = Userpilot.Config(token: token).defaultInstance(false)
        container.register(Userpilot.Config.self, value: config)
        return Storage(container: container)
    }

    private func clearStorageSuite(forToken token: String?) {
        guard let token else { return }
        UserDefaults().removePersistentDomain(forName: Storage.suiteName(forToken: token))
    }
}
