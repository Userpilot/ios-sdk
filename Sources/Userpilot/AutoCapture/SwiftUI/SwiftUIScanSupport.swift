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

    // Measured (iOS 18.3 / 26.5 simulator, sample app home screen, 31 texts):
    // a WARM scan costs ~10 ms (text map 5–9 ms, reflection ~2.5 ms). The first
    // scan of a process costs ~200 ms when unbounded — one-time Swift runtime
    // work (conformance lookups, metadata, demangling) — so the budgets below
    // are what bound that first-scan hitch; a truncated first scan is
    // completed by the next (warm) one.

    /// Blocking tap-path scan (`RescanReason.manual`, single-host refresh).
    /// Runs synchronously on the touch path so it stays tight even if it
    /// means truncating a large screen.
    static let tapPath = Budget(reflectionHostSeconds: 0.010,
                                displayListHostSeconds: 0.020,
                                totalScanSeconds: 0.025,
                                displayListMaxVisited: 1_500)

    /// Debounced background scan (`.screenAppeared` / `.touchEnded` /
    /// `.debounced`). Runs at run-loop idle, but still on main. It gets a
    /// deeper display-list walk than the tap path so long scroll views can
    /// populate titles below the initially visible section.
    static let background = Budget(reflectionHostSeconds: 0.020,
                                   displayListHostSeconds: 0.040,
                                   totalScanSeconds: 0.060,
                                   displayListMaxVisited: 8_000)

    /// Caps for the hosting-view discovery walk inside `performScan`.
    static let hostingDiscoveryMaxNodes = 5_000
    static let hostingDiscoveryMaxDepth = 80
}

// MARK: - Type-name memoization

/// Memoizes a value derived from a type's name. Demangling SwiftUI's deeply
/// generic types is the dominant cost of a scan — one `String(describing:)`
/// can build a multi-kilobyte name — and the scan asks for names on every
/// node, view and layer. Metatypes are unique and live for the whole process,
/// so each derived value is computed once per type; only the derived value
/// (usually a Bool or a short name) is stored, never the full name.
internal final class TypeNameMemo<Value> {

    enum NameSource {
        /// `String(describing:)` — demangled, unqualified.
        case swift
        /// `String(reflecting:)` — demangled, module-qualified.
        case qualified
        /// The Objective-C runtime class name (`NSStringFromClass`). Already
        /// stored on the class, so no demangling — the cheap choice for UIKit
        /// views, controllers and layers. Swift classes report their mangled
        /// name, which still contains each identifier ("…14_UIHostingView…").
        case runtimeClass
    }

    private var values: [ObjectIdentifier: Value] = [:]
    private let lock = NSLock()
    private let source: NameSource
    private let derive: (String) -> Value

    init(_ source: NameSource = .swift, _ derive: @escaping (String) -> Value) {
        self.source = source
        self.derive = derive
    }

    func callAsFunction(_ type: Any.Type) -> Value {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        if let cached = values[key] { return cached }
        let value = derive(name(of: type))
        values[key] = value
        return value
    }

    private func name(of type: Any.Type) -> String {
        switch source {
        case .swift:
            return String(describing: type)
        case .qualified:
            return String(reflecting: type)
        case .runtimeClass:
            guard let cls = type as? AnyClass else { return String(describing: type) }
            return NSStringFromClass(cls)
        }
    }
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
        hostingControllerType(type(of: viewController))
    }

    /// A SwiftUI hosting view (`_UIHostingView` and friends).
    static func isHostingView(_ view: UIView) -> Bool {
        hostingViewType(type(of: view))
    }

    /// A hosting view OR hosting scroll view — used when walking UP the view
    /// hierarchy for the accessibility-tree read, where the a11y tree usually
    /// lives on the outermost hosting/scroll host.
    static func isHostingAccessibilityAncestor(_ view: UIView) -> Bool {
        hostingAccessibilityAncestorType(type(of: view))
    }

    private static let hostingControllerType = TypeNameMemo(.runtimeClass) {
        $0.contains("HostingController") || $0.contains("HostingViewController")
    }
    private static let hostingViewType = TypeNameMemo(.runtimeClass) { $0.contains("HostingView") }
    private static let hostingAccessibilityAncestorType = TypeNameMemo(.runtimeClass) {
        $0.contains("HostingView") || $0.contains("HostingScrollView")
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
    /// host or hosting-backed tap. On top of the static config this applies the
    /// runtime gates: the session circuit breaker and the remote kill switch.
    static func shouldRun(config: Userpilot.Config, isSwiftUIHost: Bool) -> Bool {
        commonConfigEnabled(config)
            && (config.appFramework == .SwiftUI || (config.appFramework == nil && isSwiftUIHost))
            && !SwiftUICaptureHealth.isTripped
            && SwiftUICaptureRemoteGate.isAllowed(token: config.token)
    }

    private static func commonConfigEnabled(_ config: Userpilot.Config) -> Bool {
        isSupportedOS
            && config.enableInteractionAutoCapture
            && config.enableInteractionTextCapture
            && config.enableSwiftUIInteractionTitleCapture
    }

    /// The whole SwiftUI click solution — title capture, its hooks and scans,
    /// tap-end click capture, and the tap-point label filter — runs on iOS 26
    /// and later only. Below iOS 26 the SDK behaves exactly as before it.
    /// Releases newer than the last one validated on a device are covered by
    /// the circuit breaker and the remote kill switch (`disabled_ios_versions`).
    static var isSupportedOS: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
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
