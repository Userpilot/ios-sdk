//
//  DebugUIWindow.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

/// Dedicated non-key overlay window for the in-app debugger.
///
/// Sits at `.statusBar` so it is above host UI and experience overlays. Never
/// becomes key, so the host keeps keyboard and status-bar style.
internal final class DebugUIWindow: UIWindow {

    init(root: UIViewController, windowScene: UIWindowScene?) {
        if let windowScene {
            super.init(windowScene: windowScene)
            frame = windowScene.coordinateSpace.bounds
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        rootViewController = root
        windowLevel = .statusBar
        backgroundColor = .clear
        isHidden = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Hit-test only the overlay we own. `super.hitTest` also walks system
        // gesture-gate views UIKit pins to the top/bottom of a `.statusBar`
        // window; those swallow the survey/NPS close button while leaving the
        // rest of the experience tappable.
        guard let overlay = rootViewController?.view else { return nil }
        let local = overlay.convert(point, from: self)
        let hit = overlay.hitTest(local, with: event)
        if hit == nil || hit === overlay || hit === self {
            return nil
        }
        return hit
    }
}
