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
    /// Respects Config (disableScreenTitleCapture) for navigation/title fallbacks.
    static func resolvedName(for viewController: UIViewController) -> String {
        let config = Userpilot.isInitialized ? Userpilot.shared.config : nil
        let titleCaptureDisabled = config?.disableScreenTitleCapture ?? false

        if let name = viewController.userpilotSwiftUIScreenName, !name.isEmpty { return name }
        if let name = viewController.userpilotScreenName, !name.isEmpty { return name }
        if let name = findScreenName(in: viewController.view), !name.isEmpty { return name }

        if !titleCaptureDisabled, let title = viewController.navigationItem.title, !title.isEmpty {
            return title
        }
        if let tabBarTitle = extractTabBarTitle(viewController) { return tabBarTitle }
        if let rootViewType = swiftUIRootViewType(viewController) { return rootViewType }
        if !titleCaptureDisabled, let title = viewController.title, !title.isEmpty { return title }
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

    private static func swiftUIRootViewType(_ viewController: UIViewController) -> String? {
        let vcType = String(describing: type(of: viewController))
        guard vcType.contains("UIHostingController") else { return nil }
        let mirror = Mirror(reflecting: viewController)
        for child in mirror.children where child.label == "rootView" {
            let childType = String(describing: type(of: child.value))
            return childType.components(separatedBy: ".").last?
                .components(separatedBy: "<").first?
                .components(separatedBy: "(").first ?? childType
        }
        return nil
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
        var title = String(describing: viewController.classForCoder).replacingOccurrences(
            of: "ViewController", with: "")
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
        guard let config = Userpilot.isInitialized ? Userpilot.shared.config : nil,
            !config.disableScreenTitleCapture
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
//    var screenType: String {
//        return String(describing: type(of: self))
//    }

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
