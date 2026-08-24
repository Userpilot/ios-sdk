//
//  DebugConfigSnapshotFactory.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation
import os.log
import UIKit

/// Builds the Config tab snapshot from live SDK config, storage, fonts, and deep-link setup.
internal protocol DebugConfigSnapshotMaking: AnyObject {
    func create() -> DebugSnapshot
}

internal final class DebugConfigSnapshotFactory: DebugConfigSnapshotMaking {

    private let config: Userpilot.Config
    private let storage: DataStoring
    private let fontCatalog: DebugFontCataloging
    private weak var owner: Userpilot?

    init(
        config: Userpilot.Config,
        storage: DataStoring,
        fontCatalog: DebugFontCataloging,
        owner: Userpilot?
    ) {
        self.config = config
        self.storage = storage
        self.fontCatalog = fontCatalog
        self.owner = owner
    }

    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.fontCatalog = container.resolve(DebugFontCataloging.self)
        self.owner = container.owner
    }

    func create() -> DebugSnapshot {
        DebugSnapshot(
            sections: [
                sdkSection(),
                networkSection(),
                pushSection(),
                autocaptureSection(),
                deepLinkSection(),
                fontsSection()
            ]
        )
    }

    private func sdkSection() -> DebugSection {
        DebugSection(
            title: Self.sectionSDK,
            rows: [
                row("sdk_version", userpilotVersion),
                row("token", config.token),
                row("logging_enabled", String(isLoggingEnabled)),
                row("is_default", String(config.isDefault)),
                row(
                    "allow_receive_events_from_external_source",
                    String(config.allowReceiveEventsFromExternalSource)
                ),
                row("use_in_app_browser", String(config.useInAppBrowser)),
                row("ui_framework", config.appFramework?.rawValue ?? Self.unset),
                row("dialog_animation", dialogAnimationName),
                row("liquid_glass", String(config.liquidGlassEnabled)),
                row(
                    "liquid_glass_sheets_and_dialogs",
                    optionalBool(config.liquidGlassSheetsAndDialogsEnabled)
                ),
                row(
                    "liquid_glass_full_screen",
                    String(config.liquidGlassFullScreenEnabled)
                ),
                row("attached_bundles", formatList(Array(config.attachedBundleIdentifiers))),
                row("additional_properties", formatMap(config.additionalProperties)),
                row("analytics_listener", present(owner?.analyticsDelegate != nil)),
                row("experience_listener", present(owner?.experienceDelegate != nil)),
                row("navigation_handler", present(owner?.navigationDelegate != nil)),
                row("device", deviceDescription)
            ]
        )
    }

    private func networkSection() -> DebugSection {
        DebugSection(
            title: Self.sectionNetwork,
            rows: [
                row("socket_url", storage.socketURL.isEmpty ? Self.unset : storage.socketURL)
            ]
        )
    }

    private func pushSection() -> DebugSection {
        let token = storage.pushToken?.isEmpty == false ? storage.pushToken! : Self.unset
        return DebugSection(
            title: Self.sectionPush,
            rows: [
                row("apns_token", token),
                row(
                    "disable_request_push_permission",
                    String(config.disableRequestPushPermission)
                )
            ]
        )
    }

    private func autocaptureSection() -> DebugSection {
        DebugSection(
            title: Self.sectionAutocapture,
            rows: [
                row("enable_screen_auto_capture", String(config.enableScreenAutoCapture)),
                row("enable_screen_title_capture", String(config.enableScreenTitleCapture)),
                row(
                    "enable_interaction_auto_capture",
                    String(config.enableInteractionAutoCapture)
                ),
                row(
                    "enable_interaction_text_capture",
                    String(config.enableInteractionTextCapture)
                ),
                row(
                    "enable_interaction_accessibility_label_capture",
                    String(config.enableInteractionAccessibilityLabelCapture)
                ),
                row(
                    "enable_interaction_value_capture",
                    String(config.enableInteractionValueCapture)
                )
            ]
        )
    }

    private func deepLinkSection() -> DebugSection {
        let scheme = Self.defaultScheme(for: config.token)
        return DebugSection(
            title: Self.sectionDeepLink,
            rows: [
                row("host", Self.host),
                row("default_scheme", scheme),
                row(
                    "example_experience_preview",
                    "\(scheme)://\(Self.host)/experience_preview/{experienceId}"
                ),
                row("navigation_handler", present(owner?.navigationDelegate != nil))
            ]
        )
    }

    private func fontsSection() -> DebugSection {
        let appFonts = fontCatalog.appFontNames()
        let systemFonts = fontCatalog.systemFontNames()
        return DebugSection(
            title: Self.sectionFonts,
            rows: [
                row("app_font_count", String(appFonts.count)),
                row("app_fonts", formatList(appFonts)),
                row("system_font_count", String(systemFonts.count)),
                row("system_fonts", formatList(systemFonts))
            ]
        )
    }

    private var isLoggingEnabled: Bool {
        if let osLog = config.logger as? OSLog {
            return osLog !== OSLog.disabled
        }
        return true
    }

    private var dialogAnimationName: String {
        switch config.dialogAnimationType {
        case .fade: return "fade"
        case .slide: return "slide"
        }
    }

    private var deviceDescription: String {
        "\(UIDevice.current.model) (iOS \(UIDevice.current.systemVersion))"
    }

    private func optionalBool(_ value: Bool?) -> String {
        guard let value else { return Self.unset }
        return String(value)
    }

    private func formatList(_ values: [String]) -> String {
        values.isEmpty ? Self.unset : values.joined(separator: ", ")
    }

    private func formatMap(_ values: [String: Any]) -> String {
        guard !values.isEmpty else { return Self.unset }
        return values.keys.sorted().map { "\($0)=\(values[$0] ?? Self.unset)" }.joined(separator: ", ")
    }

    private func present(_ value: Bool) -> String {
        value ? Self.set : Self.unset
    }

    private func row(_ key: String, _ value: String) -> DebugProperty {
        DebugProperty(key: DebugPropertyLabel.humanize(key), value: value)
    }

    static func defaultScheme(for token: String) -> String {
        let normalized = token.replacingOccurrences(of: "STG-", with: "", options: .caseInsensitive)
        return "userpilot-\(normalized.lowercased())"
    }

    private static let sectionSDK = "SDK"
    private static let sectionNetwork = "Network"
    private static let sectionPush = "Push"
    private static let sectionAutocapture = "Autocapture"
    private static let sectionDeepLink = "Deep link"
    private static let sectionFonts = "Fonts"
    private static let unset = "—"
    private static let set = "set"
    private static let host = "sdk"
}
