//
//  DebugWindowHost.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Creates and releases the debugger window; all access belongs to the main thread.
//

import UIKit

/// Concrete UI helper. The manager owns lifecycle policy; this type owns presentation resources.
internal final class DebugWindowHost {

    var onExitRequested: (() -> Void)?

    private let eventStore: DebugEventStoring
    private let configFactory: DebugConfigSnapshotMaking
    private let userFactory: DebugUserSnapshotMaking
    private(set) var debugWindow: DebugUIWindow?

    init(
        eventStore: DebugEventStoring,
        configFactory: DebugConfigSnapshotMaking,
        userFactory: DebugUserSnapshotMaking
    ) {
        self.eventStore = eventStore
        self.configFactory = configFactory
        self.userFactory = userFactory
    }

    func show() {
        let scene = Self.resolveScene()
        if let window = debugWindow {
            if let scene, window.windowScene !== scene {
                window.windowScene = scene
                window.frame = scene.coordinateSpace.bounds
            }
            window.isHidden = false
            return
        }
        let root = DebuggerOverlayViewController(
            eventStore: eventStore, configFactory: configFactory, userFactory: userFactory
        )
        root.onExitRequested = { [weak self] in self?.onExitRequested?() }
        debugWindow = DebugUIWindow(root: root, windowScene: scene)
    }

    func hide() {
        if let overlay = debugWindow?.rootViewController?.viewIfLoaded as? DebuggerOverlayView {
            overlay.hidePanel(animated: false)
            overlay.fabView.host = nil
            overlay.onExitRequested = nil
        }
        debugWindow?.isHidden = true
        debugWindow = nil
    }

    private static func resolveScene() -> UIWindowScene? {
        UIApplication.shared.activeWindowScenes.first ?? UIApplication.shared.windows
            .first(where: { !$0.isUserpilotWindow })?.windowScene
    }
}
