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
}

internal class LinkOpener: LinkOpening {

    // MARK: - Properties

    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let logger: Logging

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
            guard let userpilot = userpilot else {
                logger.error("❌ Cannot open URL - Userpilot instance is nil")
                return
            }

            // If a delegate is provided from the host application, preference is to use it for
            // handling navigation and invoking the completion handler.
            if let delegate = userpilot.navigationDelegate {
                logger.info("🔗 UserpilotNavigationDelegate opening %{private}@", url.absoluteString)
                delegate.navigate(to: url)
                return
            }

            // If no delegate provided, fall back to automatic handling behavior provided by the
            // UIApplication - caveat, the completion callback may execute before the app has
            // fully navigated to the destination.

            // SFSafariViewController only supports HTTP and HTTPS URLs and crashes otherwise,
            // and scheme links crash the universal link opener, so check here to be sure we route safely.
            if url.isWebLink {
                if config.useInAppBrowser {
                    openInAppBrowser(url)
                } else {
                    openExternalBrowser(url)
                }
            } else {
                openSchemeLink(url)
            }
        }
    }

    // MARK: - Private Methods

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
