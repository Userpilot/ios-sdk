//
//  SwiftUICaptureGuards.swift
//  Userpilot
//
//  Runtime safety gates for SwiftUI title capture. The display-list text map
//  reads SwiftUI's private render structures through `Mirror`; those can move
//  in any iOS release (they already differ between iOS 18 and 26). Two gates
//  sit on top of the static config so a moved structure costs nothing:
//    - `SwiftUICaptureHealth`: a per-session circuit breaker. Consecutive scans
//      that find hosting views but no usable display list mean the render path
//      moved on this OS, so capture turns itself off until the next launch.
//    - `SwiftUICaptureRemoteGate`: a remote kill switch delivered with the SDK
//      settings lookup and persisted per token, so it applies from launch.
//

import Foundation

// MARK: - Circuit breaker

internal enum SwiftUICaptureHealth {

    /// Consecutive structurally failed scans before capture turns off.
    static let tripThreshold = 3

    private static let lock = NSLock()
    private static var consecutiveFailures = 0
    private static var tripped = false

    static var isTripped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tripped
    }

    /// Records one scan and returns true when this scan tripped the breaker.
    ///
    /// A scan is a structural failure when it saw hosting views but located no
    /// display list in any of them, or found text items that paired with no
    /// drawing layer. A screen that simply has no text is not a failure.
    @discardableResult
    static func recordScan(hosts: Int, locatedLists: Int, textItems: Int, pairedEntries: Int) -> Bool {
        guard hosts > 0 else { return false }
        let failed = locatedLists == 0 || (textItems > 0 && pairedEntries == 0)

        lock.lock()
        defer { lock.unlock() }
        guard !tripped else { return false }
        guard failed else {
            consecutiveFailures = 0
            return false
        }
        consecutiveFailures += 1
        tripped = consecutiveFailures >= tripThreshold
        return tripped
    }

    #if DEBUG
    // swiftlint:disable:next identifier_name
    static func _resetForTesting() {
        lock.lock()
        consecutiveFailures = 0
        tripped = false
        lock.unlock()
    }
    #endif
}

// MARK: - Remote kill switch

internal enum SwiftUICaptureRemoteGate {

    /// Key in the SDK settings lookup response. Shape:
    ///
    ///     "swiftui_title_capture": {
    ///         "enabled": true,
    ///         "disabled_ios_versions": ["27", "26.1"]
    ///     }
    ///
    /// - Key absent: allowed (and any stored rule is cleared).
    /// - `enabled: false`: off on every iOS version.
    /// - `disabled_ios_versions`: version prefixes matched on dot boundaries —
    ///   "27" matches every 27.x, "26.1" matches 26.1 and 26.1.x but not 26.10.
    static let settingsKey = "swiftui_title_capture"

    private static let defaultsKey = "swiftUITitleCaptureRemoteRule"

    private struct Rule {
        var enabled = true
        var disabledVersions: [String] = []

        init() {}

        init(json: [String: Any]) {
            enabled = (json["enabled"] as? Bool) ?? true
            let versions = json["disabled_ios_versions"] as? [Any] ?? []
            disabledVersions = versions.map { "\($0)" }
        }

        var propertyList: [String: Any] {
            ["enabled": enabled, "disabled_ios_versions": disabledVersions]
        }
    }

    private static let lock = NSLock()
    private static var rules: [String: Rule] = [:]

    /// Applies the `swiftui_title_capture` block of a settings response for
    /// `token`. Called from the settings lookup on its network queue.
    static func apply(settings json: [String: Any], token: String) {
        let block = json[settingsKey] as? [String: Any]
        let rule = block.map(Rule.init(json:)) ?? Rule()

        lock.lock()
        rules[token] = rule
        lock.unlock()

        let defaults = UserDefaults(suiteName: Storage.suiteName(forToken: token))
        if block == nil {
            defaults?.removeObject(forKey: defaultsKey)
        } else {
            defaults?.set(rule.propertyList, forKey: defaultsKey)
        }
    }

    /// False when the remote settings for `token` turn SwiftUI title capture
    /// off for this OS version.
    static func isAllowed(token: String,
                          osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> Bool {
        let rule = rule(for: token)
        guard rule.enabled else { return false }
        return !rule.disabledVersions.contains { matches($0, osVersion) }
    }

    /// True when `prefix` ("27", "26.1", "26.1.2") names `version` on dot
    /// boundaries.
    static func matches(_ prefix: String, _ version: OperatingSystemVersion) -> Bool {
        let wanted = prefix.split(separator: ".").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard !wanted.isEmpty, wanted.count <= 3, !wanted.contains(nil) else { return false }
        let actual = [version.majorVersion, version.minorVersion, version.patchVersion]
        return zip(wanted, actual).allSatisfy { $0 == $1 }
    }

    private static func rule(for token: String) -> Rule {
        lock.lock()
        defer { lock.unlock() }
        if let cached = rules[token] { return cached }
        let stored = UserDefaults(suiteName: Storage.suiteName(forToken: token))?
            .dictionary(forKey: defaultsKey)
        let rule = stored.map(Rule.init(json:)) ?? Rule()
        rules[token] = rule
        return rule
    }

    #if DEBUG
    // swiftlint:disable:next identifier_name
    static func _resetCacheForTesting() {
        lock.lock()
        rules = [:]
        lock.unlock()
    }
    #endif
}
