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

internal final class DebuggerManager: DebuggerManaging {

    private let eventStore: DebugEventStoring
    private let windowHost: DebugWindowHost
    // Main-thread-only token owns activation; no separate started/observing flags are needed.
    private var sceneObserver: NSObjectProtocol?

    var debugWindow: DebugUIWindow? { windowHost.debugWindow }

    init(container: DIContainer) {
        self.eventStore = container.resolve(DebugEventStoring.self)
        self.windowHost = DebugWindowHost(
            eventStore: eventStore,
            configFactory: container.resolve(DebugConfigSnapshotMaking.self),
            userFactory: container.resolve(DebugUserSnapshotMaking.self)
        )
    }

    deinit {
        if let sceneObserver { NotificationCenter.default.removeObserver(sceneObserver) }
        eventStore.stop()
        let host = windowHost
        // ARC may release the owning SDK on a worker; UIKit resources are released on main.
        performOnMain { host.hide() }
    }

    func show() {
        performOnMain { [weak self] in
            guard let self else { return }
            if self.sceneObserver == nil {
                self.eventStore.start()
                self.sceneObserver = NotificationCenter.default.addObserver(
                    forName: UIScene.didActivateNotification, object: nil, queue: .main
                ) { [weak self] _ in
                    guard let self, self.sceneObserver != nil else { return }
                    self.windowHost.show()
                }
            }
            self.windowHost.show()
        }
    }

    func hide() {
        performOnMain { [weak self] in
            guard let self else { return }
            if let observer = self.sceneObserver { NotificationCenter.default.removeObserver(observer) }
            self.sceneObserver = nil
            self.eventStore.stop()
            self.eventStore.reset()
            self.windowHost.hide()
        }
    }

    /// Logout clears history without disabling an open debugger.
    func reset() {
        eventStore.reset()
    }
}
