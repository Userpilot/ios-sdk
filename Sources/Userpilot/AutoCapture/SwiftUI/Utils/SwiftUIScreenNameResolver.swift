//
//  SwiftUIScreenNameResolver.swift
//  Userpilot
//
//  Created by Motasem Hamed on 11/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  SwiftUIScreenNameResolver provides utilities for resolving screen names from SwiftUI
//  view controllers, collecting comprehensive screen identification data.
//

import SwiftUI
import UIKit

/// Extension providing SwiftUI screen name resolution functionality for UIViewController
extension UIViewController {

    // Resolves screen name from UIViewController with SwiftUI-specific logic
    // - Returns: The resolved screen name string
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func swiftUIScreenNameResolver() -> String {
        var info: [String: Any] = [:]

        // 1️⃣ Explicit CSQ screen name (best signal)
        if let csq = findScreenName(in: view) {
            info["userpilot_screen_name"] = csq
        }

        // 2️⃣ SwiftUI root view type (if UIHostingController)
        if let rootViewType = userpilotSwiftUIRootViewType() {
            info["swiftui_root_view"] = rootViewType
        }

        // 3️⃣ navigationTitle
        let title = navigationItem.title
        if let title, !title.isEmpty {
            info["navigation_title"] = title
        }

        // 3.5️⃣ TabBar item title
        if let tabBarTitle = extractTabBarTitle() {
            info["tab_bar_title"] = tabBarTitle
        }

        // 4️⃣ Navigation stack path (titles + class names)
        let navPath = navigationStackSignature()
        if !navPath.isEmpty {
            info["navigation_stack"] = navPath
        }

        let titles = navigationStackTitles()
        if !titles.isEmpty {
            info["navigation_stack_titles"] = titles.joined(separator: " > ")
        }

        // 5️⃣ Presentation context
        info["presentation"] = presentationContext()

        // 6️⃣ ViewController class name (fallback)
        info["view_controller_class"] = String(describing: type(of: self))

        // 7️⃣ SwiftUI container hints (sheet / popover / etc)
        info["swiftui_container"] = detectSwiftUIContainer()

        // 8️⃣ Trait collection snapshot
        info["traits"] = traitSignature()

        // 9️⃣ Accessibility identifiers (if any)
        if let accID = view.accessibilityIdentifier {
            info["accessibility_identifier"] = accID
        }

        // 🔟 View hierarchy fingerprint (hashed)
        info["view_fingerprint"] = viewFingerprint(view)

        // 🖨 Log all collected data
        print("🧭 Screen Identification Data:")
        info.forEach { key, value in
            print("• \(key): \(value)")
        }

        // Return the screen name using priority order
        // 1. Explicit screen name (best signal)
        if let userpilotScreenName = info["userpilot_screen_name"] as? String {
            return userpilotScreenName
        }

        // 2. Navigation title (if exists and in a navigation stack)
        if let title = info["navigation_title"] as? String {
            return title
        }

        // 3. TabBar title (use this for root tab views)
        if let tabBarTitle = info["tab_bar_title"] as? String {
            return tabBarTitle
        }

        // 4. SwiftUI root view type
        if let rootViewType = info["swiftui_root_view"] as? String {
            return rootViewType
        }

        // 5. Navigation stack titles
        if let stackTitles = info["navigation_stack_titles"] as? String, !stackTitles.isEmpty {
            return stackTitles
        }

        // 6. Fallback to view controller class name
        return info["view_controller_class"] as? String
            ?? String(describing: type(of: self))
    }

    /// Extracts the SwiftUI root view type from a UIHostingController
    /// - Returns: The root view type name or nil
    func userpilotSwiftUIRootViewType() -> String? {
        let vcType = String(describing: type(of: self))
        guard vcType.contains("UIHostingController") else { return nil }

        let mirror = Mirror(reflecting: self)
        for child in mirror.children where child.label == "rootView" {
            let childType = String(describing: type(of: child.value))
            return cleanSwiftUIViewTypeName(childType)
        }

        return nil
    }

    /// Extracts the TabBar item title from the view controller
    /// - Returns: The tab bar title or nil
    private func extractTabBarTitle() -> String? {
        // Check if this view controller has a tab bar item
        if let tabBarItem = tabBarItem,
           let title = tabBarItem.title,
           !title.isEmpty {
            return title
        }

        // If within a tab bar controller, get the selected tab's title
        if let tabBarController = tabBarController {
            // Get the selected view controller's tab bar item
            if let selectedVC = tabBarController.selectedViewController {
                // Check if the current view controller is the selected one or within it
                if isViewController(containedIn: selectedVC) {
                    if let title = selectedVC.tabBarItem?.title, !title.isEmpty {
                        return title
                    }
                }
            }

            // Alternative: Find which tab this VC belongs to
            if let viewControllers = tabBarController.viewControllers {
                for (index, tabVC) in viewControllers.enumerated() where isViewController(containedIn: tabVC) {
                    if let title = tabVC.tabBarItem?.title, !title.isEmpty {
                        return title
                    }
                    // Fallback to index-based naming
                    return "Tab \(index + 1)"
                }
            }
        }

        return nil
    }

    /// Checks if a view controller is contained within another
    /// - Parameter container: The container view controller to check
    /// - Returns: True if contained, false otherwise
    private func isViewController(containedIn container: UIViewController) -> Bool {
        if self === container {
            return true
        }

        // Check if it's within a navigation controller
        if let navController = container as? UINavigationController {
            return navController.viewControllers.contains(where: { $0 === self })
        }

        // Check if it's a child view controller
        if container.children.contains(where: { $0 === self }) {
            return true
        }

        // Check recursively in children
        for child in container.children where isViewController(containedIn: child) {
            return true
        }

        return false
    }

    /// Cleans up SwiftUI view type names by removing prefixes and generics
    /// - Parameter fullType: The full type name
    /// - Returns: The cleaned type name
    private func cleanSwiftUIViewTypeName(_ fullType: String) -> String {
        // Remove module prefix (e.g., "MyApp.ContentView" -> "ContentView")
        // Remove generics (e.g., "ModifiedContent<ContentView, _BackgroundStyleModifier>" -> "ModifiedContent")
        // Remove parentheses (e.g., "View()" -> "View")
        return
            fullType
            .components(separatedBy: ".").last?
            .components(separatedBy: "<").first?
            .components(separatedBy: "(").first ?? fullType
    }

    /// Finds screen name set via SwiftUI modifier in view hierarchy
    /// - Parameter view: The view to search in
    /// - Returns: The screen name or nil
    private func findScreenName(in view: UIView) -> String? {
        // Check current view first (most specific)
        if let name = view.up_screenName, !name.isEmpty {
            return name
        }

        // Search subviews (breadth-first for better performance)
        // Prioritize views that are likely to contain SwiftUI content
        for subview in view.subviews {
            // Check if this subview has a screen name
            if let name = subview.up_screenName, !name.isEmpty {
                return name
            }
        }

        // Recursive search as fallback
        for subview in view.subviews {
            if let name = findScreenName(in: subview) {
                return name
            }
        }

        return nil
    }

    /// Gets navigation stack titles from navigation controller
    /// - Returns: Array of navigation titles
    private func navigationStackTitles() -> [String] {
        guard let nav = navigationController else {
            return []
        }

        return nav.viewControllers.compactMap {
            let title = $0.navigationItem.title
            return (title?.isEmpty == false) ? title : nil
        }
    }

    /// Gets navigation stack signature with titles and class names
    /// - Returns: Formatted navigation stack string
    private func navigationStackSignature() -> String {
        guard let nav = navigationController else { return "" }

        return nav.viewControllers
            .map {
                let title = $0.navigationItem.title ?? ""
                let cls = String(describing: type(of: $0))
                return title.isEmpty ? cls : "\(cls)(\(title))"
            }
            .joined(separator: " > ")
    }

    /// Determines the presentation context of the view controller
    /// - Returns: Presentation context string
    private func presentationContext() -> String {
        var parts: [String] = []

        if presentingViewController != nil {
            parts.append("modal")
        }
        if navigationController != nil {
            parts.append("navigation")
        }
        if tabBarController != nil {
            parts.append("tab")
        }

        return parts.isEmpty ? "root" : parts.joined(separator: "|")
    }

    /// Detects the SwiftUI container type
    /// - Returns: Container type string
    private func detectSwiftUIContainer() -> String {
        let name = String(describing: type(of: self))

        if name.contains("Popover") {
            return "popover"
        }
        if name.contains("Presentation") {
            return "sheet_or_fullscreen"
        }
        if name.contains("UIHosting") {
            return "hosting_controller"
        }

        return "unknown"
    }

    /// Gets trait collection signature for device characteristics
    /// - Returns: Formatted trait signature string
    private func traitSignature() -> String {
        let traitCollection = traitCollection

        return [
            "style:\(traitCollection.userInterfaceStyle)",
            "hSize:\(traitCollection.horizontalSizeClass)",
            "vSize:\(traitCollection.verticalSizeClass)"
        ].joined(separator: "|")
    }

    /// Creates a view hierarchy fingerprint for identification
    /// - Parameter view: The root view to fingerprint
    /// - Returns: Hashed fingerprint string
    private func viewFingerprint(_ view: UIView) -> String {
        func walk(_ view: UIView, into result: inout String) {
            result += String(describing: type(of: view))
            view.subviews.forEach { walk($0, into: &result) }
        }

        var structure = ""
        walk(view, into: &structure)

        return String(structure.hashValue)
    }
}

// MARK: - UIView Extension for Screen Name Storage

/// Associated object key for storing screen names
private var screenNameKey: UInt8 = 0

/// Extension providing screen name storage functionality for UIView
extension UIView {
    // Gets or sets the screen name associated with this view
    // swiftlint:disable:next identifier_name
    var up_screenName: String? {
        get { objc_getAssociatedObject(self, &screenNameKey) as? String }
        set {
            objc_setAssociatedObject(
                self, &screenNameKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
