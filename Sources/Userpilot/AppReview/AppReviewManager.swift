//
//  AppReviewManager.swift
//  Userpilot SDK
//
//  Created by Userpilot on 14/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Requests the host app's native store review prompt in its foreground scene.
//

import StoreKit
import UIKit

internal protocol AppReviewManaging: AnyObject {
    func requestReview()
}

internal final class AppReviewManager: AppReviewManaging {
    private let sessionMonitor: SessionMonitoring

    init(container: DIContainer) {
        sessionMonitor = container.resolve(SessionMonitoring.self)
    }

    /// StoreKit decides whether to show a prompt and does not report a submitted review.
    func requestReview() {
        // An explicit main-queue closure also satisfies the modern StoreKit API's actor isolation.
        DispatchQueue.main.async { [weak self] in
            guard self?.sessionMonitor.isAppActive == true else { return }

            if #available(iOS 14.0, *) {
                guard let scene = UIApplication.shared.mainWindowScene else { return }
                if #available(iOS 16.0, *) {
                    AppStore.requestReview(in: scene)
                } else {
                    SKStoreReviewController.requestReview(in: scene)
                }
            } else {
                // iOS 13 uses the process-level API, including apps without a scene lifecycle.
                SKStoreReviewController.requestReview()
            }
        }
    }
}
