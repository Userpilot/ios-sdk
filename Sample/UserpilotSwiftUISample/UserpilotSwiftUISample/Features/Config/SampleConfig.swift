//
//  SampleConfig.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Persists sample-only settings and builds the SDK configuration on the next launch.
//

import Foundation
import Userpilot

struct SampleConfig {
    var token = ""
    var values: [ConfigFlag: Bool] = [:]

    subscript(flag: ConfigFlag) -> Bool {
        get { values[flag] ?? flag.defaultValue }
        set { values[flag] = newValue }
    }

    static func load(defaults: UserDefaults = .standard) -> SampleConfig {
        var result = SampleConfig(token: defaults.string(forKey: "sample.appToken") ?? "")
        for flag in ConfigFlag.allCases {
            result[flag] = defaults.object(forKey: "sample.config." + flag.rawValue) as? Bool ?? flag.defaultValue
        }
        return result
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(token.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "sample.appToken")
        for flag in ConfigFlag.allCases {
            defaults.set(self[flag], forKey: "sample.config." + flag.rawValue)
        }
    }

    func sdkConfig() -> Userpilot.Config {
        Userpilot.Config(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
            .logging(enabled: self[.loggingEnabled])
            .enableUseInAppBrowser(self[.useInAppBrowser])
            .defaultInstance(self[.defaultInstance])
            .allowReceiveEventsFromExternalSource(self[.allowReceiveEventsFromExternalSource])
            .disableRequestPushNotificationsPermission(self[.disableRequestPushNotificationsPermission])
            .enableScreenAutoCapture(self[.enableScreenAutoCapture])
            .enableInteractionAutoCapture(self[.enableInteractionAutoCapture])
            .enableInteractionTextCapture(self[.enableInteractionTextCapture])
            .enableInteractionAccessibilityLabelCapture(self[.enableInteractionAccessibilityLabelCapture])
            .enableInteractionValueCapture(self[.enableInteractionValueCapture])
            .enableScreenTitleCapture(self[.enableScreenTitleCapture])
            .enableSwiftUIButtonAutoCapture(self[.enableSwiftUIButtonAutoCapture])
            .appFramework(.SwiftUI)
    }
}
