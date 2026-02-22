//
//  AutoPropertyDecorator.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `AutoPropertyDecorator` class provides automatic property decoration for analytics events,
//  including system, device, locale, network, app, and session properties.
//

import Foundation
import UIKit
import CoreTelephony

// MARK: - Protocol

/**
 Defines the interface for providing automatic and app-level properties.
 */
internal protocol AutoPropertyDecoratoring: AnyObject {
    /// System, device, locale, network and session properties captured automatically.
    var autoProperties: [String: Any] { get }
    /// Application-level properties (name, bundle ID, version, build).
    var appProperties: [String: Any] { get }
}

// MARK: - AutoPropertyDecorator

/**
 Collects and exposes a comprehensive set of auto-captured properties for analytics.
 */
internal class AutoPropertyDecorator {

    // MARK: - Dependencies

    private let config: Userpilot.Config

    // MARK: - Init

    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
    }

    // MARK: - Static Auto Properties (lazy — stable for app process lifetime)

    /// Fixed system/device/locale properties. Evaluated once and cached.
    private lazy var userpilotAutoProperties: [String: Any] = {
        [
            // ── Platform ─────────────────────────────────────────────────────
            // Required: "platform_type" = "iOS"
            Constants.AutoProperty.osKey: "iOS",
            Constants.AutoProperty.manufacturerKey: "Apple",
            Constants.AutoProperty.osVersionKey: UIDevice.current.systemVersion,
            // Required: "library_version"
            Constants.AutoProperty.libraryVersionKey: userpilotVersion,
            // Userpilot SDK type
            Constants.AutoProperty.sdkTypeKey: "iOS Native",

            // ── Device Hardware ──────────────────────────────────────────────
            // Raw sysctl model identifier, e.g. "iPhone16,1"
            Constants.AutoProperty.deviceModelKey: deviceModelIdentifier,
            // "phone" | "tablet"
            Constants.AutoProperty.deviceTypeKey: deviceType,
            // User-assigned device name
            Constants.AutoProperty.deviceNameKey: UIDevice.current.name,
            // Whether running in Xcode Simulator — shown as "Simulator" in required props
            Constants.AutoProperty.isSimulatorKey: isSimulator,
            // Jailbreak heuristic
            Constants.AutoProperty.isJailbrokenKey: isJailbroken,
            // CPU / memory / storage
            Constants.AutoProperty.processorCountKey: ProcessInfo.processInfo.processorCount,
            Constants.AutoProperty.totalRAMKey: totalRAMBytes,
            Constants.AutoProperty.totalDiskSpaceKey: totalDiskSpace,
            Constants.AutoProperty.freeDiskSpaceKey: freeDiskSpace,

            // ── Screen ────────────────────────────────────────────────────────
            Constants.AutoProperty.screenWidthKey: Int(UIScreen.main.bounds.size.width),
            Constants.AutoProperty.screenHeightKey: Int(UIScreen.main.bounds.size.height),
            Constants.AutoProperty.screenScaleKey: screenScale,

            // ── Locale & Region ───────────────────────────────────────────────
            Constants.AutoProperty.localeKey: localeIdentifier,
            // BCP-47 language tag
            Constants.AutoProperty.languageKey: preferredLanguage,
            // ISO 3166-1 alpha-2
            Constants.AutoProperty.countryCodeKey: countryCode,
            Constants.AutoProperty.currencyCodeKey: currencyCode,
            Constants.AutoProperty.countryNameKey: countryName,

            // ── Timezone ──────────────────────────────────────────────────────
            Constants.AutoProperty.timezoneKey: timezoneIdentifier,
            // Offset in minutes from GMT
            Constants.AutoProperty.timezoneOffsetMinutesKey: timezoneOffsetMinutes,
            // Convenience hours variant
            Constants.AutoProperty.timezoneOffsetHoursKey: timezoneOffsetHours,

            // ── Network / Carrier ─────────────────────────────────────────────
            Constants.AutoProperty.carrierNameKey: carrierName,
            Constants.AutoProperty.radioTechnologyKey: radioTechnology,

            // ── Static System State ───────────────────────────────────────────
            // These are less likely to change mid-session but are not truly dynamic,
            // so we capture them once. Battery and visibility are in dynamicProperties.
            Constants.AutoProperty.isLowPowerModeKey: ProcessInfo.processInfo.isLowPowerModeEnabled,
            Constants.AutoProperty.isDarkModeKey: UITraitCollection.current.userInterfaceStyle == .dark
        ]
    }()

    /// Application-level properties — stable for the app process lifetime.
    private lazy var userpilotAppProperties: [String: Any] = {
        [
            Constants.AutoProperty.appIdentifierKey: Bundle.main.identifier,
            Constants.AutoProperty.appNameKey: Bundle.main.displayName,
            Constants.AutoProperty.appVersionKey: Bundle.main.version,
            Constants.AutoProperty.appBuildKey: Bundle.main.buildNumber,
            Constants.AutoProperty.appIsSwiftUIKey: Bundle.main.isSwiftUI
        ]
    }()
}

// MARK: - Auto Property Calculation

extension AutoPropertyDecorator {

    // MARK: - Helpers: Device Model

    /// Raw sysctl model string, e.g. "iPhone16,1" or "x86_64" on Simulator.
    private var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<CChar>.size) {
                String(cString: UnsafePointer<CChar>($0))
            }
        }
    }

    // MARK: - Helpers: Jailbreak

    /// Basic heuristic jailbreak detection. Always false on Simulator.
    private var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
        #endif
    }

    // MARK: - Helpers: Network / Carrier

    /// Mobile carrier name, or "unknown".
    private var carrierName: String {
        let info = CTTelephonyNetworkInfo()
        if let providers = info.serviceSubscriberCellularProviders {
            return providers.values.compactMap { $0.carrierName }.first ?? "unknown"
        }
        return "unknown"
    }

    /// Current radio access technology mapped to a friendly string.
    /// iOS 14.1+ NR/NRNSA constants are guarded with availability checks.
    private var radioTechnology: String {
        let info = CTTelephonyNetworkInfo()
        guard let radioDict = info.serviceCurrentRadioAccessTechnology,
              let tech = radioDict.values.first else {
            return "unknown"
        }

        // 5G — CTRadioAccessTechnologyNR and NRNSA are only available on iOS 14.1+
        if #available(iOS 14.1, *) {
            if tech == CTRadioAccessTechnologyNR || tech == CTRadioAccessTechnologyNRNSA {
                return "5G"
            }
        }

        switch tech {
        case CTRadioAccessTechnologyLTE:
            return "LTE"
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB:
            return "3G"
        case CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyGPRS:
            return "2G"
        default:
            return tech
        }
    }

    // MARK: - Helpers: Locale & Region

    /// BCP-47 language tag, e.g. "en-US".
    private var preferredLanguage: String {
        return Locale.preferredLanguages.first ?? Locale.current.identifier
    }

    /// IANA timezone identifier, e.g. "Asia/Jerusalem".
    private var timezoneIdentifier: String {
        return TimeZone.current.identifier
    }

    /// Timezone offset in **minutes** from GMT, e.g. 120 for UTC+2.
    private var timezoneOffsetMinutes: Int {
        return TimeZone.current.secondsFromGMT() / 60
    }

    /// Timezone offset in **hours** as a Double, e.g. 2.0 for UTC+2.
    private var timezoneOffsetHours: Double {
        return Double(TimeZone.current.secondsFromGMT()) / 3600.0
    }

    /// ISO 3166-1 alpha-2 region/country code, e.g. "US".
    private var countryCode: String {
        return Locale.current.regionCode ?? "unknown"
    }

    /// ISO 4217 currency code, e.g. "USD".
    private var currencyCode: String {
        return Locale.current.currencyCode ?? "unknown"
    }

    /// Full locale identifier, e.g. "en_US".
    private var localeIdentifier: String {
        return Locale.current.identifier
    }

    // MARK: - Helpers: Screen

    private var screenScale: Double {
        return Double(UIScreen.main.scale)
    }

    // MARK: - Helpers: Disk & Memory

    private var totalDiskSpace: Int64 {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let val = attrs[.systemSize] as? Int64 else { return -1 }
        return val
    }

    private var freeDiskSpace: Int64 {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let val = attrs[.systemFreeSize] as? Int64 else { return -1 }
        return val
    }

    private var totalRAMBytes: Int64 {
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }

    // MARK: - Helpers: Device Type

    private var deviceType: String {
        return UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "phone"
    }

    /// Country name in English
    private var countryName: String {
        guard let regionCode = Locale.current.regionCode else { return "unknown" }
        return Locale(identifier: "en_US").localizedString(forRegionCode: regionCode) ?? "unknown"
    }

    // MARK: - Helpers: Simulator flag

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

}

// MARK: - AutoPropertyDecoratoring Conformance

extension AutoPropertyDecorator: AutoPropertyDecoratoring {

    var autoProperties: [String: Any] {
        return userpilotAutoProperties
    }

    var appProperties: [String: Any] {
        return userpilotAppProperties
    }
}
