//
//  DebuggerManager.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns debugger activation and scene observation for one SDK instance.
//

import Foundation
import UIKit

/// The per-instance entry point; hiding the debugger ends recording and clears its history.
internal protocol DebuggerManaging: AnyObject {
    func show()
    func hide()
    func reset()
}

internal final class DebuggerManager: DebuggerManaging, LifecycleDelegate {

    private let eventStore: DebugEventStoring
    private let windowHost: DebugWindowHost
    private let lifecycleMonitor: LifecycleMonitoring
    // Main owns activation; lifecycle subscription follows this feature state.
    private var isStarted = false

    var debugWindow: DebugUIWindow? { windowHost.debugWindow }

    init(container: DIContainer) {
        self.eventStore = container.resolve(DebugEventStoring.self)
        self.lifecycleMonitor = container.resolve(LifecycleMonitoring.self)
        self.windowHost = DebugWindowHost(
            eventStore: eventStore,
            configFactory: container.resolve(DebugConfigSnapshotMaking.self),
            userFactory: container.resolve(DebugUserSnapshotMaking.self)
        )
        windowHost.onExitRequested = { [weak self] in self?.hide() }
    }

    deinit {
        lifecycleMonitor.removeDelegate(self)
        eventStore.stop()
        let host = windowHost
        // ARC may release the owning SDK on a worker; UIKit resources are released on main.
        performOnMain { host.hide() }
    }

    func show() {
        performOnMain { [weak self] in
            guard let self else { return }
            if !self.isStarted {
                self.isStarted = true
                self.eventStore.start()
                self.lifecycleMonitor.addDelegate(self, replayCurrentState: false)
            }
            self.windowHost.show()
        }
    }

    func hide() {
        performOnMain { [weak self] in
            guard let self else { return }
            self.lifecycleMonitor.removeDelegate(self)
            self.isStarted = false
            self.eventStore.stop()
            self.eventStore.reset()
            self.windowHost.hide()
        }
    }

    func onSceneActive() {
        if isStarted { windowHost.show() }
    }

    /// Logout clears history without disabling an open debugger.
    func reset() {
        eventStore.reset()
    }
}
