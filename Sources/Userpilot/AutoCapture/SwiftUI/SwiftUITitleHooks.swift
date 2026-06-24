//
//  SwiftUITitleHooks.swift
//  Userpilot
//
//  Small glue between the SDK's existing tap/lifecycle paths and the SwiftUI
//  title-capture subsystem:
//    - UIView helpers used by the enrichment hook in `handleRegularViewTap`.
//    - The `viewDidAppear` swizzle target that schedules a rescan when a screen
//      appears (registered by `AutoCaptureSwizzler`, gated by the coordinator).
//

// swiftlint:disable identifier_name
// swiftlint:disable:previous blanket_disable_command

import UIKit

// MARK: - UIView helpers for the enrichment hook

internal extension UIView {

    /// Cheap superview-chain check: is this view rendered inside a SwiftUI
    /// hosting view? Used to gate the resolver so it never runs for plain UIKit.
    var up_isInsideHostingView: Bool {
        var current: UIView? = self
        while let view = current {
            if SwiftUIDetection.isHostingView(view) {
                return true
            }
            current = view.superview
        }
        return false
    }

    /// Walks DOWN from `self` through subviews whose frame contains `windowPoint`
    /// (window coordinates), returning the first that has `flag` set. Bounded to
    /// the thin point-containing path, not the whole tree.
    ///
    /// This closes the pure-SwiftUI redact/ignore gap: the policy modifier's
    /// carrier sets its flag on a descendant whose frame contains the tap, which
    /// the SDK's upward responder-chain gate can't see when the tap resolves to
    /// an ancestor hosting view. Identity + geometry match, so it never
    /// over-flags the wrong control and fails safe on overlap.
    func up_flagInSubtree(containing windowPoint: CGPoint, _ flag: KeyPath<UIView, Bool>) -> Bool {
        let local = convert(windowPoint, from: nil)   // `nil` == window space
        guard bounds.contains(local) else { return false }
        if self[keyPath: flag] { return true }
        return subviews.contains { $0.up_flagInSubtree(containing: windowPoint, flag) }
    }
}

// MARK: - viewDidAppear scan trigger

internal extension UIViewController {

    /// Swizzled in place of `viewDidAppear(_:)` (registered by
    /// `AutoCaptureSwizzler.swizzleSwiftUITitleScanScheduling`). Schedules a
    /// debounced, idle-gated SwiftUI rescan when a screen appears.
    ///
    /// `viewDidAppear` (not `viewWillAppear`) is used deliberately: the views
    /// must already be in the window for the reflection / display-list scan to
    /// see them.
    @objc func userpilot__viewDidAppear_swiftUIScan(_ animated: Bool) {
        // After the swap this calls the original viewDidAppear.
        self.userpilot__viewDidAppear_swiftUIScan(animated)

        guard let userpilot = Userpilot.shared else { return }
        guard !userpilot.autoCaptureCoordinator.isStopped else { return }
        let config = userpilot.config
        guard SwiftUITitleCapturePolicy.shouldRun(
            config: config,
            isSwiftUIHost: isSwiftUIHostingController
        ) else { return }
        #if DEBUG
        SwiftUIScanLog.log("viewDidAppear vc=\(type(of: self))")
        #endif
        // Invalidate the cached snapshot for the new screen, then schedule the
        // (debounced) scan that repopulates it. A fast first tap before the scan
        // fires triggers a synchronous prepare scan instead of resolving stale.
        SwiftUIScanCache.shared.markScreenChanged()
        SwiftUIScanCache.shared.scheduleRescan(reason: .screenAppeared)
    }

    private var isSwiftUIHostingController: Bool {
        String(describing: type(of: self)).contains("HostingController")
    }
}
