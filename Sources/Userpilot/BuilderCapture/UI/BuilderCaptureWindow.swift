//
//  BuilderCaptureWindow.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Hosts capture controls in the admitted window scene.
//

import UIKit

// MARK: - BuilderCaptureWindow

/// Window hosting capture-mode UI for one Userpilot instance.
internal final class BuilderCaptureWindow: UIWindow {

    // MARK: Initialization

    /// Shows the window synchronously in the admitted scene so UIKit can present confirmation.
    init(rootViewController: UIViewController, hostWindow: UIWindow, owningInstance: Userpilot?) {
        if let scene = hostWindow.windowScene {
            super.init(windowScene: scene)
            // `UIWindow(windowScene:)` leaves `frame = .zero`, and a zero frame
            // keeps the root view controller's view from ever becoming visible.
            self.frame = scene.coordinateSpace.bounds
        } else {
            super.init(frame: hostWindow.bounds)
        }

        self.rootViewController = rootViewController
        self.backgroundColor = .clear
        self.windowLevel = Self.windowLevel(for: owningInstance)

        // Claim the window for the owning instance's autocapture scope, so a tap
        // inside capture UI attributes to the right tenant. Mirrors what
        // `ExperienceOverlayWindow` does for the same reason.
        owningInstance?.config.attach(windows: [self])

        self.isHidden = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Hit Testing

    /// Passes through hits on the window, root view and iPad root wrapper; controls retain their hits.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event), hitView !== self else {
            return nil
        }

        if hitView === rootViewController?.view {
            return nil
        }

        if let rootView = rootViewController?.view, hitView.subviews.first === rootView {
            return nil
        }

        return hitView
    }

    // MARK: Window Level

    /// Capture-window level above experience overlays, offset by the owner's registration index.
    private static func windowLevel(for instance: Userpilot?) -> UIWindow.Level {
        guard let token = instance?.config.token,
              let index = UserpilotRuntime.shared.instanceRegistry.registrationIndex(forToken: token) else {
            return .statusBar
        }
        return .statusBar + CGFloat(index)
    }

}
