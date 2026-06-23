//
//  ScreenNameResolver.swift
//  Userpilot
//
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Unified screen name resolution for both SwiftUI and UIKit. Single priority order
//  and one entry point (ScreenNameResolver.resolvedName(for:)).
//

import UIKit

// MARK: - ScreenNameResolver (unified resolution)

/// Unified screen name resolution for SwiftUI and UIKit.
/// Single priority order and one entry point (ScreenNameResolver.resolvedName(for:)).
internal final class ScreenNameResolver {

    /// Single entry point: resolved screen name for the given view controller.
    /// Respects Config (`enableScreenTitleCapture`) for navigation/title fallbacks.
    /**
     viewController.userpilotSwiftUIScreenName (if non-empty)
     viewController.userpilotScreenName (if non-empty)
     findScreenName(in: viewController.view) (if non-empty)
     tabBarControllerPreferredTitle(viewController) — when embedded in a tab bar, the tab bar
       controller’s title / navigation title (e.g. “Tabs Test”) before the selected tab’s label
     viewController.navigationItem.title (if non-empty, and enableScreenTitleCapture == true)
     extractTabBarTitle(viewController) (tab item title, e.g. “Home”)
     swiftUIRootViewType(viewController)
     viewController.title (if non-empty, and enableScreenTitleCapture == true)
     navigationStackTitlesString(viewController) (if non-empty)
     Fallback: displayName(viewController)
     */
    static func resolvedName(for viewController: UIViewController) -> String {
        // Resolve via the OWNING Userpilot instance so e.g. an embedded SDK that
        // disabled `enableScreenTitleCapture` is honoured for its own VCs even when
        // the host app's instance has it enabled.
        let config = InstanceResolver.shared.target(forViewController: viewController)?.config
        let titleCaptureEnabled = config?.enableScreenTitleCapture ?? true

        if let name = viewController.userpilotSwiftUIScreenName, !name.isEmpty { return name }
        if let name = viewController.userpilotScreenName, !name.isEmpty { return name }
        if let name = findScreenName(in: viewController.view), !name.isEmpty { return name }

        if let containerTitle = tabBarControllerPreferredTitle(
            viewController, titleCaptureEnabled: titleCaptureEnabled
        ) {
            return containerTitle
        }

        if titleCaptureEnabled, let title = viewController.navigationItem.title, !title.isEmpty {
            return title
        }
        if let tabBarTitle = extractTabBarTitle(viewController) { return tabBarTitle }
        if let rootViewType = swiftUIRootViewType(viewController) { return rootViewType }
        if titleCaptureEnabled, let title = viewController.title, !title.isEmpty { return title }
        if let stackTitles = navigationStackTitlesString(viewController), !stackTitles.isEmpty {
            return stackTitles
        }

        return displayName(viewController)
    }

    /// Builds the screen path representing the navigation hierarchy.
    static func buildScreenPath(for viewController: UIViewController) -> String {
        var pathComponents: [String] = []
        var current: UIViewController? = viewController
        while let currentVC = current {
            pathComponents.insert(resolvedName(for: currentVC), at: 0)
            if let presenting = currentVC.presentingViewController {
                current = presenting
            } else if let nav = currentVC.navigationController, currentVC !== nav {
                current = nav
            } else if let tab = currentVC.tabBarController, currentVC !== tab {
                current = tab
            } else if let parent = currentVC.parent, currentVC !== parent {
                current = parent
            } else {
                break
            }
        }
        return pathComponents.joined(separator: "/")
    }

    // MARK: Private helpers

    /// When `viewController` is inside a `UITabBarController` (but is not the tab bar itself),
    /// prefer the tab bar controller’s explicit titles so screen name and navigation title reflect
    /// the container (e.g. “Tabs Test”) rather than the selected tab’s item title (e.g. “Home”).
    /// Shared by `resolvedName(for:)` and `UIViewController.userpilotScreenTitle`.
    static func tabBarControllerPreferredTitle(
        _ viewController: UIViewController,
        titleCaptureEnabled: Bool
    ) -> String? {
        guard let tab = viewController.tabBarController, tab !== viewController else { return nil }
        if let name = tab.userpilotSwiftUIScreenName, !name.isEmpty { return name }
        if let name = tab.userpilotScreenName, !name.isEmpty { return name }
        guard titleCaptureEnabled else { return nil }
        if let title = tab.navigationItem.title, !title.isEmpty { return title }
        if let title = tab.title, !title.isEmpty { return title }
        return nil
    }

    private static func extractTabBarTitle(_ viewController: UIViewController) -> String? {
        if let item = viewController.tabBarItem, let title = item.title, !title.isEmpty { return title }
        guard let tabBar = viewController.tabBarController else { return nil }
        if let selected = tabBar.selectedViewController,
            isViewController(viewController, containedIn: selected),
            let title = selected.tabBarItem?.title, !title.isEmpty {
            return title
        }
        guard let viewControllers = tabBar.viewControllers else { return nil }
        for (index, tabVC) in viewControllers.enumerated()
        where isViewController(viewController, containedIn: tabVC) {
            if let title = tabVC.tabBarItem?.title, !title.isEmpty { return title }
            return "Tab \(index + 1)"
        }
        return nil
    }

    private static func isViewController(
        _ viewController: UIViewController, containedIn container: UIViewController
    ) -> Bool {
        if viewController === container { return true }
        if let nav = container as? UINavigationController {
            return nav.viewControllers.contains { $0 === viewController }
        }
        if container.children.contains(where: { $0 === viewController }) { return true }
        return container.children.contains { isViewController(viewController, containedIn: $0) }
    }

    private static func findScreenName(in view: UIView) -> String? {
        if let name = view.userpilotScreenNameTag, !name.isEmpty { return name }
        for subview in view.subviews {
            if let name = subview.userpilotScreenNameTag, !name.isEmpty { return name }
        }
        for subview in view.subviews { if let name = findScreenName(in: subview) { return name } }
        return nil
    }

    private static func hostingRootView(from viewController: UIViewController) -> Any? {
        var currentMirror: Mirror? = Mirror(reflecting: viewController)

        while let mirror = currentMirror {
            for child in mirror.children where child.label == "rootView" {
                return child.value
            }
            currentMirror = mirror.superclassMirror
        }

        return nil
    }

    private static func swiftUIRootViewType(_ viewController: UIViewController) -> String? {
        let vcType = String(describing: type(of: viewController))
        guard vcType.contains("HostingController"),
            let rootView = hostingRootView(from: viewController)
        else { return nil }

        let childType = String(describing: type(of: rootView))
        return childType.components(separatedBy: ".").last?
            .components(separatedBy: "<").first?
            .components(separatedBy: "(").first ?? childType
    }

    private static func navigationStackTitlesString(_ viewController: UIViewController) -> String? {
        guard let nav = viewController.navigationController else { return nil }
        let titles = nav.viewControllers.compactMap { $0.navigationItem.title }.filter {
            !$0.isEmpty
        }
        return titles.isEmpty ? nil : titles.joined(separator: " > ")
    }

    static func displayName(_ viewController: UIViewController) -> String {
        var name = getViewControllerName(viewController) ?? String(describing: viewController.classForCoder)
        if name.starts(with: "UIHostingController<") { name = "UIHostingController" }
        return name
    }

    static func getViewControllerName(_ viewController: UIViewController) -> String? {
        var title = String(describing: viewController.classForCoder)
        if title.isEmpty { title = viewController.title ?? "" }
        return title.isEmpty ? nil : title
    }
}

// MARK: - Internal extensions (delegate to ScreenNameResolver + storage)

private var swiftUIScreenNameKey: UInt8 = 0
private var userpilotScreenNameTagKey: UInt8 = 0

extension UIViewController {

    var userpilotSwiftUIScreenName: String? {
        get { objc_getAssociatedObject(self, &swiftUIScreenNameKey) as? String }
        set {
            objc_setAssociatedObject(
                self, &swiftUIScreenNameKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func resolvedScreenNameForCapture() -> String {
        ScreenNameResolver.resolvedName(for: self)
    }

    func buildScreenPath() -> String {
        ScreenNameResolver.buildScreenPath(for: self)
    }

    func resolveNavigationTitle() -> String? {
        // Use the owning instance's config so navigation titles are gated by the
        // tenant whose VC this is.
        guard let config = InstanceResolver.shared.target(forViewController: self)?.config,
              config.enableScreenTitleCapture
        else { return nil }
        return userpilotScreenTitle
    }

    var displayName: String {
        ScreenNameResolver.displayName(self)
    }

    func getViewControllerName() -> String? {
        ScreenNameResolver.getViewControllerName(self)
    }

    var screenClassName: String {
        String(describing: type(of: self))
    }

    var screenType: String {
        if self is UINavigationController { return "UINavigationController" }
        if self is UITabBarController { return "UITabBarController" }
        if self is UISplitViewController { return "UISplitViewController" }
        if self is UIPageViewController { return "UIPageViewController" }
        if String(describing: type(of: self)).contains("UIHostingController") {
            return "UIHostingController"
        }
        return "UIViewController"
    }

    var isRootViewController: Bool {
        if view.window?.rootViewController === self { return true }
        if let nav = navigationController, nav.viewControllers.first === self { return true }
        if parent == nil && presentingViewController == nil { return true }
        return false
    }

    func uiKitScreenNameResolver() -> String {
        resolvedScreenNameForCapture()
    }
}

extension UIView {

    func userpilotResolvedScreenName() -> String {
        guard let viewController = closestViewController() else {
            return AutoCaptureConstants.unknownScreenHierarchyPlaceholder
        }
        return viewController.screenClassName
    }

    func closestViewController() -> UIViewController? {
        var nextResponder = self.next
        while let responder = nextResponder {
            if let viewController = responder as? UIViewController { return viewController }
            nextResponder = responder.next
        }
        return nil
    }

    var userpilotScreenNameTag: String? {
        get { objc_getAssociatedObject(self, &userpilotScreenNameTagKey) as? String }
        set {
            objc_setAssociatedObject(
                self, &userpilotScreenNameTagKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
