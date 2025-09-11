//
//  UIApplication+Extension.swift
//
//  Created by Motasem Hamed on 20/08/2024.
//
//  [Brief Description]
//  UIApplication+Extension file contains an extension of the `UIApplication` class, providing helper methods
//  for retrieving the top-most view controller and managing active window scenes.
//

import Foundation
import UIKit

internal extension UIApplication {

    // MARK: - Active Window Scenes

    /// Returns all active window scenes in the foreground.
    @available(iOS 13.0, *)
    var activeWindowScenes: [UIWindowScene] {
        self.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
    }

    /// Checks if there are any active window scenes.
    var hasActiveWindowScenes: Bool {
        if #available(iOS 13.0, *) {
            return !activeWindowScenes.isEmpty
        } else {
            return false
        }
    }

    /// Returns the active key window, considering iOS versions and multitasking.
    private var activeKeyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return self.activeWindowScenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return keyWindow
        }
    }

    // MARK: - Public API

    /// Retrieves the top-most view controller, ensuring it is executed on the main thread.
    func fetchTopViewController(completion: @escaping (UIViewController?) -> Void) {
        if Thread.isMainThread {
            completion(resolveTopViewController())
        } else {
            DispatchQueue.main.async { [weak self] in
                completion(self?.resolveTopViewController())
            }
        }
    }

    // MARK: - Private Helpers

    /// Resolves the top-most view controller starting from the root view controller.
    /// - Returns: The top-most `UIViewController`, or `nil` if none is found.
    func resolveTopViewController() -> UIViewController? {
        var window: UIWindow? = activeKeyWindow

        if window == nil {
            if #available(iOS 15.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    window = windowScene.windows.first
                }
            } else {
                window = UIApplication.shared.windows.first
            }
        }

        guard let rootViewController = window?.rootViewController else { return nil }
        return findTopViewController(from: rootViewController)
    }

    /// Recursively finds the top-most view controller starting from a given controller.
    /// - Parameter controller: The `UIViewController` to start the search from.
    /// - Returns: The top-most `UIViewController`.
    private func findTopViewController(from controller: UIViewController) -> UIViewController {
        if let navigationController = controller as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            if !visibleViewController.isBeingDismissed {
                return findTopViewController(from: visibleViewController)
            } else if let topStack = navigationController.viewControllers.last {
                return findTopViewController(from: topStack)
            } else {
                return findTopViewController(from: visibleViewController)
            }
        }

        if let tabController = controller as? UITabBarController,
           let selectedViewController = tabController.selectedViewController {
            return findTopViewController(from: selectedViewController)
        }

        if let presentedViewController = controller.presentedViewController,
           !presentedViewController.isBeingDismissed {
            return findTopViewController(from: presentedViewController)
        }

        return controller
    }
}
