//
//  SwiftUIScanSupport.swift
//  Userpilot
//
//  Shared internal helpers for the SwiftUI title-capture subsystem:
//    - `SwiftUIScanBudget`: the wall-clock / node budgets the scan paths use.
//    - `SwiftUIDetection`: the centralized hosting-view / hosting-controller
//      type-name predicates (previously duplicated as inline string checks).
//
//  Budgets are provisional safety defaults. They bound worst-case main-thread
//  cost; the final values are a device-measured tuning task (see the F3
//  instrumentation notes in REVIEW-VALIDATION-AND-FIX-PLAN_v10.md).
//

import UIKit

// MARK: - Scan budgets

internal enum SwiftUIScanBudget {

    struct Budget {
        /// Per reflection host (one `extractInventory` call).
        let reflectionHostSeconds: TimeInterval
        /// Per display-list host (one `textMap` call).
        let displayListHostSeconds: TimeInterval
        /// Whole-scan ceiling shared across all hosts in a single `performScan`.
        let totalScanSeconds: TimeInterval
        /// Node cap for walking a host's SwiftUI display list.
        let displayListMaxVisited: Int
    }

    /// Blocking first-tap scan (`RescanReason.manual`). Safety dominates; this
    /// runs synchronously on the touch path so it must stay tight even if it
    /// means truncating a large screen.
    static let tapPath = Budget(reflectionHostSeconds: 0.025,
                                displayListHostSeconds: 0.025,
                                totalScanSeconds: 0.035,
                                displayListMaxVisited: 1_500)

    /// Debounced background scan (`.screenAppeared` / `.touchEnded` /
    /// `.debounced`). Runs at run-loop idle, but still on main. It gets a
    /// deeper display-list walk than the tap path so long scroll views can
    /// populate titles below the initially visible section.
    static let background = Budget(reflectionHostSeconds: 0.070,
                                   displayListHostSeconds: 0.120,
                                   totalScanSeconds: 0.180,
                                   displayListMaxVisited: 8_000)

    /// Legacy reflection-only budget retained for narrow direct inventory scans.
    static let reflectionOnceSeconds: TimeInterval = 0.040

    /// Caps for the hosting-view discovery walk inside `performScan`.
    static let hostingDiscoveryMaxNodes = 5_000
    static let hostingDiscoveryMaxDepth = 80
}

// MARK: - Hosting detection

/// Centralized type-name predicates for SwiftUI hosting controllers / views.
/// These preserve the three DISTINCT predicate sets that previously lived inline:
///   - controller detection  (`HostingController` / `HostingViewController`)
///   - view detection         (`HostingView`)
///   - a11y-ancestor detection (`HostingView` / `HostingScrollView`)
/// Do not collapse them into one another — the semantics differ by call site.
internal enum SwiftUIDetection {

    /// A `UIHostingController` (including SwiftUI's private navigation/tab/sheet
    /// subclasses, which all carry "HostingController" in their type name).
    static func isHostingController(_ viewController: UIViewController) -> Bool {
        let name = String(describing: type(of: viewController))
        return name.contains("HostingController") || name.contains("HostingViewController")
    }

    /// A SwiftUI hosting view (`_UIHostingView` and friends).
    static func isHostingView(_ view: UIView) -> Bool {
        String(describing: type(of: view)).contains("HostingView")
    }

    /// A hosting view OR hosting scroll view — used when walking UP the view
    /// hierarchy for the accessibility-tree read, where the a11y tree usually
    /// lives on the outermost hosting/scroll host.
    static func isHostingAccessibilityAncestor(_ view: UIView) -> Bool {
        let name = String(describing: type(of: view))
        return name.contains("HostingView") || name.contains("HostingScrollView")
    }
}

// MARK: - Title-capture gating

internal enum SwiftUITitleCapturePolicy {

    /// Whether the SDK should install SwiftUI title-capture hooks/cache. This is
    /// allowed while framework auto-detection is still pending; runtime hook
    /// checks below keep UIKit-only apps from doing scan work.
    static func shouldInstall(config: Userpilot.Config) -> Bool {
        commonConfigEnabled(config) && config.appFramework != .UIKit
    }

    /// Whether a lifecycle/tap hook should run title-capture work for a SwiftUI
    /// host or hosting-backed tap.
    static func shouldRun(config: Userpilot.Config, isSwiftUIHost: Bool) -> Bool {
        commonConfigEnabled(config)
            && (config.appFramework == .SwiftUI || (config.appFramework == nil && isSwiftUIHost))
    }

    private static func commonConfigEnabled(_ config: Userpilot.Config) -> Bool {
        config.enableInteractionAutoCapture
            && config.enableInteractionTextCapture
            && config.enableSwiftUIInteractionTitleCapture
            && osVersionEnabled(config)
    }

    private static func osVersionEnabled(_ config: Userpilot.Config) -> Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return config.enableSwiftUIInteractionTitleCaptureBelowIOS26
    }
}

#if DEBUG
// MARK: - Diagnostics

/// Lightweight, greppable diagnostics for the SwiftUI title-capture pipeline.
/// DEBUG-only — compiled out of release. Filter device console by `[UP-SUI]`.
/// Each line is prefixed with a millisecond timestamp (since first log) so the
/// ordering of viewDidAppear → scan → tap → resolve is visible at a glance.
///
/// Toggle off with `SwiftUIScanLog.enabled = false`.
internal enum SwiftUIScanLog {
    static var enabled = true
    private static let start = CFAbsoluteTimeGetCurrent()

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let line = String(format: "[UP-SUI] +%9.1fms  %@", elapsedMilliseconds, message())
        // Pass the built line as an argument (not the format) so a `%` in any
        // captured title can't be misread by NSLog as a format specifier.
        NSLog("%@", line)
    }
}
#endif
