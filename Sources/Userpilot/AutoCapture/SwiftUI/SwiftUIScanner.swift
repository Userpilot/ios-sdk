//
//  SwiftUIScanner.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Reads native render geometry and reflection inventory on main within the existing scan budgets.
//

import UIKit

/// Stateless native reads only. SwiftUIScanCache owns scheduling, freshness and scan admission.
internal enum SwiftUIScanner {
    /// Phase B result across every hosting view of the window.
    struct TextMapScan {
        var entries: [DisplayListTextMap.Entry] = []
        var hostCount = 0
        var locatedLists = 0
        var textItems = 0
        var truncated = false
    }

    static func scanTextMap(
        in window: UIWindow, budget: SwiftUIScanBudget.Budget, logger: Logging?
    ) -> TextMapScan {
        let textMapDeadline = Date().addingTimeInterval(budget.totalScanSeconds)
        var result = TextMapScan()
        let hosts = DisplayListTextMap.hostingViews(
            in: window,
            maxNodes: SwiftUIScanBudget.hostingDiscoveryMaxNodes,
            maxDepth: SwiftUIScanBudget.hostingDiscoveryMaxDepth,
            scanDeadline: textMapDeadline
        )
        for host in hosts {
            if Date() > textMapDeadline {
                result.truncated = true
                break
            }
            #if DEBUG
            if ProcessInfo.processInfo.environment["UP_SUI_STRUCTURE"] == "1" {
                logger?.debugSwiftUICapture(DisplayListTextMap.debugDescribeRenderPath(of: host))
            }
            #endif
            let hostDeadline = min(Date().addingTimeInterval(budget.displayListHostSeconds), textMapDeadline)
            let scan = DisplayListTextMap.scanHost(host, deadline: hostDeadline,
                                                   maxVisited: budget.displayListMaxVisited, logger: logger)
            result.hostCount += 1
            result.locatedLists += scan.locatedDisplayList ? 1 : 0
            result.textItems += scan.textItemCount
            result.truncated = result.truncated || scan.truncated
            result.entries.append(contentsOf: scan.entries)
        }
        return result
    }

    /// Build the SwiftUI inventory by reflecting every hosting controller
    /// (shallow → deep) and merging every non-empty inventory. SwiftUI
    /// NavigationStack / TabView can split visible content across multiple
    /// hosting controllers, so keeping only the deepest non-empty host drops
    /// buttons that are still visible in a sibling/parent host.
    static func buildInventory(
        in window: UIWindow,
        budget: SwiftUIScanBudget.Budget,
        scanDeadline: Date,
        logger: Logging?
    ) -> ([SwiftUIReflection.ViewRecord], UIViewController?) {
        let controllers = SwiftUIReflection.allHostingControllers(in: window)
        let snapshots = controllers.map { host -> (records: [SwiftUIReflection.ViewRecord], host: UIViewController) in
            // Per-host reflection deadline, clamped to the whole-scan deadline so
            // a late host can never push past the total budget.
            let hostDeadline = min(Date().addingTimeInterval(budget.reflectionHostSeconds), scanDeadline)
            return (records: SwiftUIReflection.extractInventory(from: host, deadline: hostDeadline, logger: logger),
                    host: host)
        }
        let merged = Self.mergeInventories(snapshots)
        return (merged.records, merged.host ?? controllers.last)
    }

    static func mergeInventories(
        _ snapshots: [(records: [SwiftUIReflection.ViewRecord], host: UIViewController)]
    ) -> (records: [SwiftUIReflection.ViewRecord], host: UIViewController?) {
        var merged: [SwiftUIReflection.ViewRecord] = []
        var selectedHost: UIViewController?
        for snapshot in snapshots where !snapshot.records.isEmpty {
            merged.append(contentsOf: snapshot.records)
            selectedHost = snapshot.host
        }
        return (merged, selectedHost)
    }

    /// Titles the inventory marks as belonging to tappable controls. Capture is
    /// button-first: a rendered text whose title is NOT in this list never
    /// becomes a resolver-supplied title.
    static func interactiveRecords(
        in records: [SwiftUIReflection.ViewRecord]
    ) -> [(title: String, viewType: String)] {
        var seen = Set<String>()
        var out: [(String, String)] = []
        for record in records where record.isInteractive {
            if seen.insert(record.title).inserted {
                out.append((record.title, record.viewType))
            }
        }
        return out
    }

}
