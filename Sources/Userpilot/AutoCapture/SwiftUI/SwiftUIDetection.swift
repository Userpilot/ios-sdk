//
//  SwiftUIDetection.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Identifies native SwiftUI hosts without repeatedly demangling runtime type names.
//

import UIKit

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
