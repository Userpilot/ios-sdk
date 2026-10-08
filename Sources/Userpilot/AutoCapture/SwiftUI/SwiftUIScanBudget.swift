//
//  SwiftUIScanBudget.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines bounded native scan budgets for taps and deferred scans.
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
