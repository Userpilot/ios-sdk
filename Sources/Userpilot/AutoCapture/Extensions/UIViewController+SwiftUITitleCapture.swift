//
//  UIViewController+SwiftUITitleCapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Schedules native scans after the original viewDidAppear callback for the owning SDK instance.
//

import UIKit

internal extension UIViewController {

    /// Swizzled in place of `viewDidAppear(_:)` (registered by
    /// `AutoCaptureSwizzler.swizzleSwiftUIScanScheduling`). Schedules a
    /// debounced, idle-gated SwiftUI rescan when a screen appears.
    ///
    /// `viewDidAppear` (not `viewWillAppear`) is used deliberately: the views
    /// must already be in the window for the reflection / display-list scan to
    /// see them.
    @objc func userpilot__viewDidAppear_swiftUIScan(_ animated: Bool) {
        // After the swap this calls the original viewDidAppear.
        self.userpilot__viewDidAppear_swiftUIScan(animated)

        guard let userpilot = UserpilotRuntime.shared.instanceResolver.resolveOwner(from: self) else { return }
        guard !userpilot.autoCaptureCoordinator.isStopped else { return }
        let config = userpilot.config
        guard SwiftUITitleCapturePolicy.shouldRun(
            config: config,
            isSwiftUIHost: SwiftUIDetection.isHostingController(self)
        ) else { return }
        config.logger.debugSwiftUICapture("viewDidAppear vc=\(type(of: self))")
        // Invalidate the cached snapshot for the new screen, then schedule the
        // (debounced) scan that repopulates it. A fast first tap before the scan
        // fires triggers a synchronous prepare scan instead of resolving stale.
        UserpilotRuntime.shared.scanCache.markScreenChanged(logger: config.logger)
        guard let window = viewIfLoaded?.window else { return }
        UserpilotRuntime.shared.scanCache.scheduleRescan(reason: .screenAppeared, window: window, owner: userpilot)
    }
}
