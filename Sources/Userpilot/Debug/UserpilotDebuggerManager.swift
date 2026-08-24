//
//  UserpilotDebuggerManager.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation
import UIKit

/// Owns the in-app debugger overlay and event-store subscription.
internal protocol UserpilotDebuggerManaging: AnyObject {
    func show()
    func reset()
    func hide()
}

internal final class UserpilotDebuggerManager: UserpilotDebuggerManaging {

    private let eventStore: DebugEventStoring
    private let configFactory: DebugConfigSnapshotMaking
    private let userFactory: DebugUserSnapshotMaking
    private var started = false
    private var observingScenes = false

    /// Retained so `show()` can unhide without recreating the overlay (anti-blink).
    private(set) var debugWindow: DebugUIWindow?

    init(container: DIContainer) {
        self.eventStore = container.resolve(DebugEventStoring.self)
        self.configFactory = container.resolve(DebugConfigSnapshotMaking.self)
        self.userFactory = container.resolve(DebugUserSnapshotMaking.self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        debugWindow?.isHidden = true
        debugWindow = nil
    }

    func show() {
        onMain { [weak self] in
            guard let self else { return }
            if !self.started {
                self.started = true
                self.eventStore.start()
                self.startObservingScenes()
            }
            self.attachWindowIfNeeded()
        }
    }

    func reset() {
        eventStore.reset()
    }

    func hide() {
        onMain { [weak self] in
            guard let self else { return }
            self.started = false
            self.eventStore.stop()
            self.debugWindow?.isHidden = true
        }
    }

    @objc private func sceneDidActivate(_ notification: Notification) {
        guard started, notification.object is UIWindowScene else { return }
        onMain { [weak self] in
            self?.attachWindowIfNeeded()
        }
    }

    private func attachWindowIfNeeded() {
        let scene = Self.resolveScene()
        if let window = debugWindow {
            if let scene, window.windowScene !== scene {
                window.windowScene = scene
                window.frame = scene.coordinateSpace.bounds
            }
            window.isHidden = false
            return
        }
        let root = DebugOverlayViewController(
            eventStore: eventStore,
            configFactory: configFactory,
            userFactory: userFactory
        )
        debugWindow = DebugUIWindow(root: root, windowScene: scene)
    }

    private func startObservingScenes() {
        guard !observingScenes else { return }
        observingScenes = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidActivate(_:)),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    private static func resolveScene() -> UIWindowScene? {
        if let active = UIApplication.shared.activeWindowScenes.first {
            return active
        }
        return UIApplication.shared.windows
            .first(where: { !$0.isUserpilotWindow })?
            .windowScene
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
