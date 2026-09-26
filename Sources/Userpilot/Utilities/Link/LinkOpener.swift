//
//  LinkOpener.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 16/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Handles opening URLs either through a custom navigation delegate, in-app browser,
//  or external browser/scheme handler based on SDK configuration.
//

import SafariServices
import UIKit

internal protocol LinkOpening: AnyObject {
    func handleURL(_ url: URL)
    func processPendingDeepLink()
}

internal class LinkOpener: LinkOpening {

    // MARK: - Properties

    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let logger: Logging

    /// Guards `canRoute` and `pendingURL`: a deep link can arrive on the socket thread, while
    /// the gate is opened from the main thread and from wherever a host assigns its delegate.
    private let routingLock = NSLock()

    /// False until the host has had its chance to wire up — see `processPendingDeepLink()`.
    private var canRoute = false

    /// The most recent deep link received before routing opened, if any.
    ///
    /// Newest-wins is safe because only a cold-start push can land here: an experience CTA
    /// cannot fire before the host is wired, since no experience has been rendered yet.
    private var pendingURL: URL?

    /// Dependency for getting the top view controller and opening URLs. Can be mocked for testing.
    var urlOpener: TopControllerGetting & URLOpening = UIApplication.shared

    // MARK: - Initialization

    init(container: DIContainer) {
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.logger = config.logger
    }

    // MARK: - LinkOpening

    func handleURL(_ url: URL) {
        tryCatch {
            routingLock.lock()
            let canRoute = self.canRoute
            if !canRoute { pendingURL = url }
            routingLock.unlock()

            guard canRoute else {
                logger.info("🔗 Holding deep link until the host can route it")
                return
            }

            route(url)
        }
    }

    /// Opens routing and delivers a deep link held from before the host was ready.
    ///
    /// A cold-start push tap is replayed from `PushNotificationAutoConfig.register(observer:)`,
    /// which runs *inside* `Userpilot.init` — before the caller has had any chance to assign
    /// `navigationDelegate`. Routing there sends the link nowhere, so `handleURL` holds it until
    /// this is called: from `navigationDelegate`'s `didSet`, and one runloop turn after `init`
    /// returns so hosts that never set a delegate still get the URL-opening fallback.
    ///
    /// Idempotent — later calls with nothing held do nothing.
    func processPendingDeepLink() {
        routingLock.lock()
        canRoute = true
        let held = pendingURL
        pendingURL = nil
        routingLock.unlock()

        guard let held = held else { return }
        route(held)
    }

    // MARK: - Private Methods

    /// Delivers `url` to the host on the main thread.
    ///
    /// Both branches reach host UI — the navigation delegate drives the app's navigation stack,
    /// and the fallback presents a view controller — so neither is safe off main.
    private func route(_ url: URL) {
        performOn(.main) { [weak self] in
            guard let self = self else { return }
            guard let userpilot = self.userpilot else {
                self.logger.error("❌ Cannot open URL - Userpilot instance is nil")
                return
            }

            // If a delegate is provided from the host application, preference is to use it for
            // handling navigation and invoking the completion handler.
            if let delegate = userpilot.navigationDelegate {
                self.logger.info(
                    "🔗 UserpilotNavigationDelegate opening %{private}@", url.absoluteString)
                delegate.navigate(to: url)
                return
            }

            // If no delegate provided, fall back to automatic handling behavior provided by the
            // UIApplication - caveat, the completion callback may execute before the app has
            // fully navigated to the destination.

            // SFSafariViewController only supports HTTP and HTTPS URLs and crashes otherwise,
            // and scheme links crash the universal link opener, so check here to be sure we route safely.
            if url.isWebLink {
                if self.config.useInAppBrowser {
                    self.openInAppBrowser(url)
                } else {
                    self.openExternalBrowser(url)
                }
            } else {
                self.openSchemeLink(url)
            }
        }
    }

    /// Opens a URL in the in-app Safari view controller.
    private func openInAppBrowser(_ url: URL) {
        logger.info("🌐 In-app browser opening %{private}@", url.absoluteString)

        guard let topViewController = urlOpener.topViewController() else {
            logger.error("❌ Cannot present in-app browser - no top view controller available")
            // Fallback to external browser
            openExternalBrowser(url)
            return
        }

        let safariVC = SFSafariViewController(url: url)
        topViewController.present(safariVC, animated: true)
    }

    /// Opens a URL in the device's external browser (Safari).
    private func openExternalBrowser(_ url: URL) {
        logger.info("🌍 External browser opening %{private}@", url.absoluteString)
        urlOpener.open(url)
    }

    /// Opens a URL with a custom scheme (e.g., mailto:, tel:, app-specific schemes).
    private func openSchemeLink(_ url: URL) {
        logger.info("🔗 Scheme link opening %{private}@", url.absoluteString)
        urlOpener.open(url)
    }
}
