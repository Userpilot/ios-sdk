//
//  DeepLinkHandler.swift
//  Userpilot SDK
//
//  Created by Userpilot on 16/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Handles deep link URLs for the Userpilot SDK: experience previews and Builder QR capture links.
//  Manages deferred URL handling when app scenes are not yet active.
//

import UIKit

internal protocol DeepLinkHandling: AnyObject {
    func didHandleURL(_ url: URL) -> Bool
}

internal final class DeepLinkHandler: DeepLinkHandling, LifecycleDelegate {

    // MARK: - Nested Types

    enum Action: Hashable {
        /// Preview for draft content with experience ID and optional query parameters
        case preview(experienceID: String, queryItems: [URLQueryItem])

        /// `sdk/capture?capture_id&platform&token`; nil when a value is missing or blank, or the platform is not iOS.
        case capture(link: CaptureLink?)

        /// A capture link whose `platform` is Android, refused before capture starts.
        case otherPlatformCapture

        init?(url: URL, token: String) {
            guard url.scheme?.lowercased() == "userpilot-\(token)".lowercased(), url.host == "sdk" else { return nil }
            let parts = url.path.split(separator: "/").map(String.init)
            switch (parts.first, parts.count) {
            case ("experience_preview", 2):
                self = .preview(experienceID: parts[1], queryItems: url.queryItems)
            case (Constants.BuilderCapture.Link.route, 1):
                let values = DeepLinkHandler.captureLinkValues(in: url)
                self = CaptureLink.isForOtherPlatform(values[.platform])
                    ? .otherPlatformCapture
                    : .capture(link: CaptureLink.from(
                        captureID: values[.captureID], platform: values[.platform], token: values[.token]))
            default:
                return nil
            }
        }
    }

    // MARK: - Properties

    private weak var container: DIContainer?
    private let lifecycleMonitor: LifecycleMonitoring
    private lazy var config = container?.resolve(Userpilot.Config.self)
    private lazy var logger = container?.resolve(Userpilot.Config.self).logger

    /// Main-thread only. Identical links received before scene activation share one pending action.
    private var actionsToHandle: Set<Action> = []

    /// Dependency for getting the top view controller. Can be mocked for testing.
    var topControllerGetting: TopControllerGetting = UIApplication.shared

    // MARK: - Initialization

    init(container: DIContainer) {
        self.container = container
        self.lifecycleMonitor = container.resolve(LifecycleMonitoring.self)
    }

    // MARK: - DeepLinkHandling

    func didHandleURL(_ url: URL) -> Bool {
        guard
            let token = config?.token,
            let action = Action(url: url, token: token)
        else {
            logger?.debug("🔗 Deep link not handled: %{public}@", url.redactedDescription)
            return false
        }

        logger?.info("🔗 Deep link handling: %{public}@", url.redactedDescription)
        // Only the failing field's name; never a link value.
        switch action {
        case .capture(link: nil):
            let values = Self.captureLinkValues(in: url)
            let field = CaptureLink.invalidField(
                captureID: values[.captureID], platform: values[.platform], token: values[.token])
            logger?.error("❌ Capture link rejected: %{public}@", field?.rawValue ?? "")
        case .otherPlatformCapture:
            logger?.error("❌ Capture link rejected: %{public}@", CaptureLink.Field.platform.rawValue)
        case .capture, .preview:
            break
        }

        performOnMain { [weak self] in
            self?.dispatch(action: action)
        }

        return true
    }

    // MARK: - Private Methods

    /// The capture link's URL-decoded query values, keyed by field; a raw `+` stays `+`, as the token may
    /// contain one. The values are never logged.
    private static func captureLinkValues(in url: URL) -> [CaptureLink.Field: String] {
        var values: [CaptureLink.Field: String] = [:]
        for field in CaptureLink.Field.allCases {
            values[field] = url.queryValue(for: field.rawValue)
        }
        return values
    }

    /// Dispatches an action either immediately or defers it until a scene becomes active.
    private func dispatch(action: Action) {
        if topControllerGetting.hasActiveWindowScenes {
            handle(action: action)
            return
        }

        let needsActivationObserver = actionsToHandle.isEmpty
        actionsToHandle.insert(action)
        if needsActivationObserver {
            // One observer owns the whole batch until the next scene activation.
            lifecycleMonitor.addDelegate(self, replayCurrentState: false)
            logger?.debug("🔗 Deep link deferred until scene activates")
        }
    }

    /// Handles the deep link action by triggering the appropriate SDK functionality.
    private func handle(action: Action) {
        tryCatch {
            switch action {
            case let .preview(experienceID, queryItems):
                logger?.info("🚀 Triggering experience preview: %{public}@", experienceID)
                container?.resolve(ExperiencesPublishing.self).triggerPreviewExperience(
                    experienceID,
                    queryItems
                )
            case let .capture(link):
                let coordinator = container?.resolve(BuilderCaptureCoordinating.self)
                if let link {
                    coordinator?.start(link: link)
                } else {
                    coordinator?.rejectInvalidLink()
                }
            case .otherPlatformCapture:
                container?.resolve(BuilderCaptureCoordinating.self).rejectOtherPlatformLink()
            }
        }
    }

    func onSceneActive() {
        performOnMain { [weak self] in
            guard let self else { return }

            // Release this batch before callbacks, which may defer another link reentrantly.
            let pendingActions = self.actionsToHandle
            self.actionsToHandle.removeAll()
            self.lifecycleMonitor.removeDelegate(self)
            self.logger?.info("✅ Scene activated, handling %d deferred deep link(s)", pendingActions.count)

            pendingActions.forEach(self.handle(action:))
        }
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
