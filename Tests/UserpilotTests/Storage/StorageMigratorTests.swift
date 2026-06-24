//
//  StorageMigratorTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class StorageMigratorTests: XCTestCase {

    private static let legacySuiteName = "com.userpilot.test.legacy.suite"
    private static let tokenedSuiteName = "com.userpilot.test.tokened.suite"
    private static let tokenedSuiteNameB = "com.userpilot.test.tokened.suite.b"
    private static let systemSuiteName = "com.userpilot.test.system.suite"

    private static let tokenA = "TOKEN_A"
    private static let tokenB = "TOKEN_B"

    override func setUpWithError() throws {
        for name in [
            Self.legacySuiteName,
            Self.tokenedSuiteName,
            Self.tokenedSuiteNameB,
            Self.systemSuiteName
        ] {
            UserDefaults().removePersistentDomain(forName: name)
        }
    }

    override func tearDownWithError() throws {
        for name in [
            Self.legacySuiteName,
            Self.tokenedSuiteName,
            Self.tokenedSuiteNameB,
            Self.systemSuiteName
        ] {
            UserDefaults().removePersistentDomain(forName: name)
        }
    }

    // MARK: - Tests

    func testMigration_copiesAllKnownKeysFromLegacy() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))

        legacy.set("user-123", forKey: Storage.Key.userId.rawValue)
        legacy.set("anonymous-abc", forKey: Storage.Key.anonymousUserId.rawValue)
        legacy.set("push-token-data", forKey: Storage.Key.pushToken.rawValue)

        StorageMigrator.runIfNeeded(target: target, legacy: legacy)

        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "user-123")
        XCTAssertEqual(target.string(forKey: Storage.Key.anonymousUserId.rawValue), "anonymous-abc")
        XCTAssertEqual(target.string(forKey: Storage.Key.pushToken.rawValue), "push-token-data")
        XCTAssertEqual(target.integer(forKey: StorageMigrator.migrationVersionKey),
                       StorageMigrator.currentMigrationVersion,
                       "Migration must record the applied version to skip re-running on next launch")
    }

    func testMigration_copiesKnownKeysWithSupportedUserDefaultsTypesAndIgnoresUnknownKeys() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))

        let sessionDate = Date(timeIntervalSince1970: 123)
        let configurationDate = Date(timeIntervalSince1970: 456)

        legacy.set("wss://socket.userpilot.io", forKey: Storage.Key.socketURL.rawValue)
        legacy.set("user-123", forKey: Storage.Key.userId.rawValue)
        legacy.set("anonymous-abc", forKey: Storage.Key.anonymousUserId.rawValue)
        legacy.set("{\"user_id\":\"user-123\"}", forKey: Storage.Key.user.rawValue)
        legacy.set("{\"user_id\":\"temporary\"}", forKey: Storage.Key.temporaryUser.rawValue)
        legacy.set(sessionDate, forKey: Storage.Key.sessionDate.rawValue)
        legacy.set(configurationDate, forKey: Storage.Key.configurationDate.rawValue)
        legacy.set("push-token-data", forKey: Storage.Key.pushToken.rawValue)
        legacy.set("ignore-me", forKey: "unknown.key")

        StorageMigrator.runIfNeeded(target: target, legacy: legacy)

        XCTAssertEqual(target.string(forKey: Storage.Key.socketURL.rawValue), "wss://socket.userpilot.io")
        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "user-123")
        XCTAssertEqual(target.string(forKey: Storage.Key.anonymousUserId.rawValue), "anonymous-abc")
        XCTAssertEqual(target.string(forKey: Storage.Key.user.rawValue), "{\"user_id\":\"user-123\"}")
        XCTAssertEqual(target.string(forKey: Storage.Key.temporaryUser.rawValue), "{\"user_id\":\"temporary\"}")
        XCTAssertEqual(target.object(forKey: Storage.Key.sessionDate.rawValue) as? Date, sessionDate)
        XCTAssertEqual(target.object(forKey: Storage.Key.configurationDate.rawValue) as? Date, configurationDate)
        XCTAssertEqual(target.string(forKey: Storage.Key.pushToken.rawValue), "push-token-data")
        XCTAssertNil(target.object(forKey: "unknown.key"))
    }

    func testMigration_isIdempotent() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))

        legacy.set("u-1", forKey: Storage.Key.userId.rawValue)
        StorageMigrator.runIfNeeded(target: target, legacy: legacy)

        // Mutate legacy after migration completed — second run must NOT pick up the change.
        legacy.set("u-2", forKey: Storage.Key.userId.rawValue)
        StorageMigrator.runIfNeeded(target: target, legacy: legacy)

        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "u-1",
                       "Migration must not re-copy after the completion sentinel is set")
    }

    func testMigration_doesNotOverwriteExistingV2Data() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        // Target already populated by v2 — must never be overwritten by legacy.
        target.set("v2-real-user", forKey: Storage.Key.userId.rawValue)
        legacy.set("legacy-stale-user", forKey: Storage.Key.userId.rawValue)

        StorageMigrator.runIfNeeded(
            target: target,
            legacy: legacy,
            system: system,
            token: Self.tokenA
        )

        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "v2-real-user")
        XCTAssertEqual(target.integer(forKey: StorageMigrator.migrationVersionKey),
                       StorageMigrator.currentMigrationVersion)
        XCTAssertNil(system.string(forKey: StorageMigrator.legacyOwnerTokenKey),
                     "A legacy-owner claim must not be written when no copy happened")
    }

    func testMigration_marksCompletedWhenLegacyIsEmpty() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        StorageMigrator.runIfNeeded(
            target: target,
            legacy: legacy,
            system: system,
            token: Self.tokenA
        )

        // Even with no data to migrate, the version marker is set so subsequent
        // launches skip the check immediately.
        XCTAssertEqual(target.integer(forKey: StorageMigrator.migrationVersionKey),
                       StorageMigrator.currentMigrationVersion)
        for key in Storage.Key.allCases {
            XCTAssertNil(target.object(forKey: key.rawValue))
        }
        XCTAssertNil(system.string(forKey: StorageMigrator.legacyOwnerTokenKey),
                     "A legacy-owner claim must not be written when no legacy data exists")
    }

    func testMigration_marksCompletedWhenLegacySuiteUnavailable() throws {
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))

        StorageMigrator.runIfNeeded(target: target, legacy: nil)

        XCTAssertEqual(target.integer(forKey: StorageMigrator.migrationVersionKey),
                       StorageMigrator.currentMigrationVersion)
    }

    func testMigration_noopWhenTargetSuiteUnavailable() {
        let legacy = UserDefaults(suiteName: Self.legacySuiteName)
        legacy?.set("user-x", forKey: Storage.Key.userId.rawValue)

        // Must not crash and must not touch legacy.
        StorageMigrator.runIfNeeded(target: nil, legacy: legacy)

        XCTAssertEqual(legacy?.string(forKey: Storage.Key.userId.rawValue), "user-x")
    }

    // MARK: - First-token-wins

    func testMigration_recordsLegacyOwnerTokenAfterCopying() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        legacy.set("shared-legacy-user", forKey: Storage.Key.userId.rawValue)

        StorageMigrator.runIfNeeded(
            target: target,
            legacy: legacy,
            system: system,
            token: Self.tokenA
        )

        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "shared-legacy-user")
        XCTAssertEqual(
            system.string(forKey: StorageMigrator.legacyOwnerTokenKey),
            Self.tokenA,
            "First tenant to migrate must record the claim under the system suite"
        )
    }

    func testMigration_secondTenantDoesNotCopyAlreadyClaimedLegacy() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let targetA = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))
        let targetB = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteNameB))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        legacy.set("shared-legacy-user", forKey: Storage.Key.userId.rawValue)

        // Tenant A migrates first; claim is recorded.
        StorageMigrator.runIfNeeded(
            target: targetA,
            legacy: legacy,
            system: system,
            token: Self.tokenA
        )
        XCTAssertEqual(targetA.string(forKey: Storage.Key.userId.rawValue), "shared-legacy-user")

        // Tenant B starts fresh; the claim must steer it away from copying.
        StorageMigrator.runIfNeeded(
            target: targetB,
            legacy: legacy,
            system: system,
            token: Self.tokenB
        )

        XCTAssertNil(targetB.string(forKey: Storage.Key.userId.rawValue),
                     "Second tenant must not inherit legacy data already claimed by the first")
        XCTAssertEqual(targetB.integer(forKey: StorageMigrator.migrationVersionKey),
                       StorageMigrator.currentMigrationVersion,
                       "Second tenant still records the applied version to skip future attempts")
        XCTAssertEqual(
            system.string(forKey: StorageMigrator.legacyOwnerTokenKey),
            Self.tokenA,
            "Claim must remain owned by the first tenant"
        )
    }

    func testMigration_sameTokenSecondLaunchSkipsViaCompletionSentinel() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        legacy.set("u1", forKey: Storage.Key.userId.rawValue)
        StorageMigrator.runIfNeeded(target: target, legacy: legacy, system: system, token: Self.tokenA)

        // Same tenant launches again — even if legacy changes, completion sentinel
        // short-circuits the second pass.
        legacy.set("u2", forKey: Storage.Key.userId.rawValue)
        StorageMigrator.runIfNeeded(target: target, legacy: legacy, system: system, token: Self.tokenA)

        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "u1")
    }

    func testMigration_honorsLegacyOwnerTokenWrittenByOlderBuilds() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteNameB))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        legacy.set("legacy-user", forKey: Storage.Key.userId.rawValue)
        system.set(Self.tokenA, forKey: "__userpilotLegacyOwnerToken")

        StorageMigrator.runIfNeeded(
            target: target,
            legacy: legacy,
            system: system,
            token: Self.tokenB
        )

        XCTAssertNil(target.string(forKey: Storage.Key.userId.rawValue))
        XCTAssertEqual(target.integer(forKey: StorageMigrator.migrationVersionKey),
                       StorageMigrator.currentMigrationVersion)
        XCTAssertNil(system.string(forKey: StorageMigrator.legacyOwnerTokenKey),
                     "Skipping due to an old-format claim must not rewrite the new claim key")
        XCTAssertEqual(system.string(forKey: "__userpilotLegacyOwnerToken"), Self.tokenA)
    }

    func testMigration_matchingLegacyOwnerTokenFromOlderBuildCanCopyAndUpgradesClaimKey() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: Self.legacySuiteName))
        let target = try XCTUnwrap(UserDefaults(suiteName: Self.tokenedSuiteName))
        let system = try XCTUnwrap(UserDefaults(suiteName: Self.systemSuiteName))

        legacy.set("legacy-user", forKey: Storage.Key.userId.rawValue)
        system.set(Self.tokenA, forKey: "__userpilotLegacyOwnerToken")

        StorageMigrator.runIfNeeded(
            target: target,
            legacy: legacy,
            system: system,
            token: Self.tokenA
        )

        XCTAssertEqual(target.string(forKey: Storage.Key.userId.rawValue), "legacy-user")
        XCTAssertEqual(system.string(forKey: StorageMigrator.legacyOwnerTokenKey), Self.tokenA)
        XCTAssertEqual(system.string(forKey: "__userpilotLegacyOwnerToken"), Self.tokenA)
    }
}

// swiftlint:enable all
