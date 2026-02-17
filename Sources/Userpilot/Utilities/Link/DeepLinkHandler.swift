//
//  DeepLinkHandler.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 16/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Handles deep link URLs for the Userpilot SDK, including experience preview links.
//  Manages deferred URL handling when app scenes are not yet active.
//

import UIKit

internal protocol DeepLinkHandling: AnyObject {
    func didHandleURL(_ url: URL) -> Bool
}

internal class DeepLinkHandler: DeepLinkHandling {

    // MARK: - Nested Types

    enum Action: Hashable {
        /// Preview for draft content with experience ID and optional query parameters
        case preview(experienceID: String, queryItems: [URLQueryItem])

        init?(url: URL, token: String) {
            let scheme = url.scheme?.lowercased()
            // QR code link uses prod token always so we need to convert the stg token to prod token
            let normalizedToken = token.replacingOccurrences(of: "STG-", with: "", options: .caseInsensitive)
            let isValidScheme = scheme == "userpilot-\(normalizedToken)".lowercased()
            guard isValidScheme, url.host == "sdk" else { return nil }

            // Supported paths:
            // userpilot-{token}://sdk/experience_preview/{experience_id}

            let pathTokens = url.path.split(separator: "/").map { String($0) }

            if pathTokens.count == 2, pathTokens[0] == "experience_preview" {
                self = .preview(experienceID: pathTokens[1], queryItems: url.queryItems)
            } else {
                return nil
            }
        }
    }

    // MARK: - Properties

    private weak var container: DIContainer?
    private lazy var config = container?.resolve(Userpilot.Config.self)
    private lazy var logger = container?.resolve(Userpilot.Config.self).logger

    /// This is a set because a `SceneDelegate` has a `Set<UIOpenURLContext>` to handle.
    private var actionsToHandle: Set<Action> = []

    /// Dependency for getting the top view controller. Can be mocked for testing.
    var topControllerGetting: TopControllerGetting = UIApplication.shared

    // MARK: - Initialization

    init(container: DIContainer) {
        self.container = container
    }

    // MARK: - DeepLinkHandling

    func didHandleURL(_ url: URL) -> Bool {
        guard
            let token = config?.token,
            let action = Action(url: url, token: token)
        else {
            logger?.debug("🔗 Deep link not handled: %{public}@", url.absoluteString)
            return false
        }

        logger?.info("🔗 Deep link handling: %{public}@", url.absoluteString)

        if Thread.isMainThread {
            dispatch(action: action)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.dispatch(action: action)
            }
        }

        return true
    }

    // MARK: - Private Methods

    /// Dispatches an action either immediately or defers it until a scene becomes active.
    private func dispatch(action: Action) {
        if topControllerGetting.hasActiveWindowScenes {
            // UIScene is already active and we can handle the action immediately.
            handle(action: action)
        } else if actionsToHandle.isEmpty {
            actionsToHandle.insert(action)

            // Set up a single observer to trigger handling any action(s).
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(sceneDidActivate),
                name: UIScene.didActivateNotification,
                object: nil
            )
            logger?.debug("🔗 Deep link deferred until scene activates")
        } else {
            actionsToHandle.insert(action)
        }
    }

    /// Handles the deep link action by triggering the appropriate SDK functionality.
    private func handle(action: Action) {
        tryCatch {
            switch action {
            case let .preview(experienceID, queryItems):
                logger?.info("🚀 Triggering experience preview: %{public}@", experienceID)
                container?.resolve(ExperiencesPublishing.self).triggerPreviewExperience(
                    experienceID, queryItems)
            }
        }
    }

    @objc
    private func sceneDidActivate() {
        logger?.info("✅ Scene activated, handling %d deferred deep link(s)", actionsToHandle.count)

        actionsToHandle.forEach(handle(action:))

        // Reset after handling to avoid handling notifications multiple times.
        actionsToHandle.removeAll()
        NotificationCenter.default.removeObserver(
            self, name: UIScene.didActivateNotification, object: nil)
    }
}

// MARK: - Public API

// Note: this is an extension compared to `Userpilot.didHandle(_:)` because `UIOpenURLContext` is part of UIKit.
extension Userpilot {

    /// Verifies if an incoming URL is intended for the Userpilot SDK.
    /// - Parameter URLContexts: One or more `UIOpenURLContext` objects.
    /// Each object contains one URL to open and any additional information needed to open that URL.
    /// - Returns: The set of `UIOpenURLContext` objects that were not intended for the Userpilot SDK.
    ///
    /// If the `url` is an Userpilot URL, this function may launch a flow preview or otherwise alter the UI state.
    ///
    /// This function is intended to be called added at the top of your
    ///  `UISceneDelegate`'s `scene(_:openURLContexts:)` function:
    /// ```swift
    /// guard !userpilot.filterAndHandle(URLContexts) else { return }
    /// ```
    @available(iOS 13.0, *)
    @discardableResult
    @objc
    public func filterAndHandle(_ URLContexts: Set<UIOpenURLContext>) -> Set<UIOpenURLContext> {
        URLContexts.filter { !didHandleURL($0.url) }
    }
}
