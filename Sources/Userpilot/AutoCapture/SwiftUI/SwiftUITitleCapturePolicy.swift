//
//  SwiftUITitleCapturePolicy.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Centralizes title and tap timing gates using the owning SDK instance configuration.
//

import Foundation

// MARK: - Title-capture gating

internal enum SwiftUITitleCapturePolicy {

    /// The switch for the whole SwiftUI button solution — tap-end click capture,
    /// the tap-point label filter and title capture. Off (the default) means the
    /// SDK captures interactions exactly as it does without the solution.
    static func isFeatureEnabled(_ config: Userpilot.Config) -> Bool {
        isSupportedOS
            && config.enableInteractionAutoCapture
            && config.enableSwiftUIButtonAutoCapture
    }

    /// SwiftUI apps capture clicks at touch END, and only for real taps (single
    /// finger, short, little movement): SwiftUI has no UIControl target-action
    /// to tell a tap from the start of a scroll, so touch-began capture would log
    /// a click for every scroll that starts on a button. UIKit apps and wrapper
    /// hosts keep touch-began capture. Each touch is still captured at most once.
    static func capturesClicksOnTapEnd(_ config: Userpilot.Config) -> Bool {
        isFeatureEnabled(config) && config.appFramework == .SwiftUI && !config.isWrapperSDK
    }

    /// Whether the SDK should install SwiftUI title-capture hooks/cache. This is
    /// allowed while framework auto-detection is still pending; runtime hook
    /// checks below keep UIKit-only apps from doing scan work.
    static func shouldInstall(config: Userpilot.Config) -> Bool {
        commonConfigEnabled(config) && config.appFramework != .UIKit
    }

    /// Whether a lifecycle/tap hook should run title-capture work for a SwiftUI
    /// host or hosting-backed tap. On top of the static config this applies the
    /// local session circuit breaker.
    static func shouldRun(config: Userpilot.Config, isSwiftUIHost: Bool) -> Bool {
        commonConfigEnabled(config)
            && (config.appFramework == .SwiftUI || (config.appFramework == nil && isSwiftUIHost))
            && !SwiftUICaptureHealth.isTripped
    }

    private static func commonConfigEnabled(_ config: Userpilot.Config) -> Bool {
        isFeatureEnabled(config) && config.enableInteractionTextCapture
    }

    /// The whole SwiftUI click solution — title capture, its hooks and scans,
    /// tap-end click capture, and the tap-point label filter — runs on iOS 26
    /// and later only, and only with `enableSwiftUIButtonAutoCapture`. Below
    /// iOS 26 the SDK behaves exactly as before it.
    /// The local circuit breaker stops title capture after repeated failures to
    /// read SwiftUI internals. Tap-end capture and the label filter use public
    /// UIKit only and stay on.
    static var isSupportedOS: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}
