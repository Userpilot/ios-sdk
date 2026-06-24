//
//  StorageMigrator.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  One-shot, idempotent migration from SDK v1's legacy (token-less) `UserDefaults`
//  suite into the host app instance's tokened v2 suite.
//
//  Scope (intentionally narrow):
//   - Runs exactly once per (token, install). The per-tenant
//     `migrationVersionKey` records the highest applied migration version and
//     is the authoritative "do not migrate again" check.
//   - First-token-wins across instances: a process-shared system suite
//     records the first token that absorbed the legacy data; every subsequent
//     tenant sees that claim and skips the copy, so the same legacy bytes never
//     end up in two tenants.
//   - Defensive against re-running over already-populated v2 data.
//
//

import Foundation

/// Owns the v1 → v2 storage migration. Stateless; the migration record itself
/// lives in `UserDefaults` so reinstalls and re-launches behave correctly.
internal enum StorageMigrator {

    /// Highest storage-migration schema version this SDK build knows how to apply.
    ///
    /// Version history:
    ///  - `1`: v1 (token-less) → v2 (per-tenant tokened) storage move.
    ///
    /// When a new migration step is needed, bump this constant and gate the step
    /// on the stored `migrationVersionKey` value so older installs upgrade in order.
    internal static let currentMigrationVersion = 1

    /// Per-tenant v2 key holding the highest migration version already applied
    /// (absent / `0` means "nothing migrated yet"). Replaces the previous boolean
    /// completion marker so future migrations can branch on the exact version.
    internal static let migrationVersionKey = "userpilot.storage.migrationVersion"

    /// Key inside the process-shared `__system` suite holding the token of the
    /// first tenant that absorbed legacy v1 data. Used by every subsequent
    /// tenant to decide whether legacy is theirs to copy (matching token) or
    /// already claimed (different token).
    internal static let legacyOwnerTokenKey = "userpilot.storage.legacyOwnerToken"

    /// Pre-unification name of `legacyOwnerTokenKey`. Read-only fallback so a
    /// claim written by an older build still steers later tenants away from
    /// re-absorbing the same legacy bytes after this rename.
    private static let legacyOwnerTokenKeyV0 = "__userpilotLegacyOwnerToken"

    // MARK: - Public API

    /// Production entry point.
    ///
    /// Resolves the legacy (token-less) and v2 (tokened) `UserDefaults` suites
    /// from `Storage`, plus the process-shared system claim suite, then runs
    /// the migration. Idempotent — safe to call on every launch.
    ///
    /// - Parameter token: The instance's configured token.
    static func runIfNeeded(forToken token: String) {
        let target = UserDefaults(suiteName: Storage.suiteName(forToken: token))
        let legacy = UserDefaults(suiteName: Storage.legacyUserDefaultSuiteName)
        let system = UserDefaults(suiteName: Storage.legacySystemSuiteName)
        runIfNeeded(target: target, legacy: legacy, system: system, token: token)
    }

    /// Test-friendly entry point that accepts injected suites.
    ///
    /// Production code should call `runIfNeeded(forToken:)` instead. Tests use
    /// this overload to drive the migrator with synthetic suites without
    /// touching real production storage.
    static func runIfNeeded(
        target: UserDefaults?,
        legacy: UserDefaults?,
        system: UserDefaults? = nil,
        token: String = ""
    ) {
        guard let target = target else { return }

        // Already at (or beyond) the current version — fast path.
        if target.integer(forKey: migrationVersionKey) >= currentMigrationVersion { return }

        // Defensive: if the new suite already holds any known key, do not
        // overwrite it from legacy. Protects the rare reinstall-then-rollback
        // path where v2 ran, wrote real data, and a future repair invocation
        // would otherwise copy stale legacy data on top.
        if hasAnyKnownKey(in: target) {
            markMigrated(target)
            return
        }

        // First-token-wins claim. Only the first tenant ever absorbs legacy
        // data; subsequent tenants see the claim and skip the copy so the
        // same legacy bytes do not appear in two tenants. Falls back to the
        // pre-rename claim key so claims written by older builds are honored.
        if let system = system, !token.isEmpty {
            let claimed = system.string(forKey: legacyOwnerTokenKey)
                ?? system.string(forKey: legacyOwnerTokenKeyV0)
            if let claimed = claimed, claimed != token {
                markMigrated(target)
                return
            }
        }

        guard let legacy = legacy, hasAnyKnownKey(in: legacy) else {
            // Nothing to migrate — fresh install or already cleaned up.
            markMigrated(target)
            return
        }

        copyKnownKeys(from: legacy, into: target)
        if let system = system, !token.isEmpty {
            system.set(token, forKey: legacyOwnerTokenKey)
        }
        markMigrated(target)
    }

    /// Records `currentMigrationVersion` in the tenant suite so every subsequent
    /// launch short-circuits until a newer migration version ships.
    private static func markMigrated(_ target: UserDefaults) {
        target.set(currentMigrationVersion, forKey: migrationVersionKey)
    }

    // MARK: - Internals

    /// Returns `true` if `defaults` contains any of the storage keys the SDK uses.
    private static func hasAnyKnownKey(in defaults: UserDefaults) -> Bool {
        return Storage.Key.allCases.contains { defaults.object(forKey: $0.rawValue) != nil }
    }

    /// Copies every known storage key from `source` into `destination`.
    private static func copyKnownKeys(from source: UserDefaults, into destination: UserDefaults) {
        for key in Storage.Key.allCases {
            guard let value = source.object(forKey: key.rawValue) else { continue }
            destination.set(value, forKey: key.rawValue)
        }
    }
}
