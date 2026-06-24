//
//  View+ScanPolicy.swift
//  Userpilot
//
//  Public SwiftUI view modifiers for opting a screen out of the accessibility
//  scan (the resolver's Stage A). Use these on screens that hit the
//  nested-lazy accessibility hang (Apple bug FB21851974).
//
//  Both modifiers resolve the SwiftUI view's hosting UIViewController via a
//  hidden background representable (the same bridge style as `userpilotLabel`)
//  and register it with `SwiftUIScanPolicy`. Display-list capture keeps running,
//  so visible screen/control titles can still be captured without Stage A.
//
//  The one-shot scan is a no-op when SwiftUI title capture is disabled, so
//  these modifiers are safe to ship in client code unconditionally.
//

import SwiftUI
import UIKit

public extension View {

    /// Instructs Userpilot autocapture to skip the accessibility read for the
    /// hosting view controller of this view, for that controller's lifetime.
    ///
    /// Use this to prevent main-thread UI hangs when rendering complex, nested
    /// lazy containers (`LazyVStack` / `LazyHStack` inside another lazy view)
    /// that mutate state during `.onAppear` (Apple bug FB21851974). Reflection +
    /// display-list capture still run, so the screen's titles are still
    /// captured — this only stops Userpilot from triggering the underlying
    /// SwiftUI defect (VoiceOver or the Accessibility Inspector can still
    /// trigger it).
    func userpilotSkipAccessibilityScan() -> some View {
        background(SwiftUIScanPolicyInjector(mode: .skipOnly))
    }

    /// Opts the hosting view controller out of the accessibility read and runs
    /// one title-capture scan for the current rendered/materialized screen.
    /// For mostly-static screens: one scan, then taps resolve from the cached
    /// display-list text map without repeated scan scheduling.
    func userpilotScanOnce() -> some View {
        background(SwiftUIScanPolicyInjector(mode: .scanOnce))
    }
}

// MARK: - Private bridge

private struct SwiftUIScanPolicyInjector: UIViewRepresentable {

    enum Mode { case skipOnly, scanOnce }
    let mode: Mode

    func makeUIView(context: Context) -> SwiftUIScanPolicyCarrierView {
        let view = SwiftUIScanPolicyCarrierView()
        view.mode = mode
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: SwiftUIScanPolicyCarrierView, context: Context) {
        uiView.mode = mode
        uiView.applyIfPossible()
    }
}

/// Hidden view that resolves its hosting view controller and registers the
/// scan-policy opt-out.
private final class SwiftUIScanPolicyCarrierView: UIView {

    var mode: SwiftUIScanPolicyInjector.Mode = .skipOnly
    private var didScanOnce = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyIfPossible()
    }

    func applyIfPossible() {
        guard window != nil, let host = up_nearestViewController else { return }

        SwiftUIScanPolicy.skipAccessibility(for: host)

        if mode == .scanOnce, !didScanOnce {
            didScanOnce = true
            SwiftUIScanCache.shared.scanOnceCurrentScreen(for: host)
        }
    }
}
