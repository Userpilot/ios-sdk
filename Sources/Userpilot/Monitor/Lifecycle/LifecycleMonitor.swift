//
//  LifecycleMonitor.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns process-wide native observation and broadcasts to weak feature delegates.
//  Session policy and scene-specific presentation remain in their feature owners.
//

import UIKit

/// Membership is thread-safe; native observation, catch-up and delivery run on main.
internal protocol LifecycleMonitoring: AnyObject {
    func addDelegate(_ delegate: LifecycleDelegate, replayCurrentState: Bool)
    func removeDelegate(_ delegate: LifecycleDelegate)
}

/// One runtime-owned monitor serves every SDK instance without retaining their services.
/// Construction is passive. The first subscriber starts observation for the runtime's lifetime.
internal final class LifecycleMonitor: LifecycleMonitoring {
    private let delegates = MulticastDelegate<LifecycleDelegate>()
    private let notificationCenter: NotificationCenter
    private let applicationState: () -> UIApplication.State
    // Only main installs observers. Their removal is safe on the thread releasing an isolated monitor.
    private var observers: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = .default,
        applicationState: @escaping () -> UIApplication.State = { UIApplication.shared.applicationState }
    ) {
        self.notificationCenter = notificationCenter
        self.applicationState = applicationState
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }

    func addDelegate(_ delegate: LifecycleDelegate, replayCurrentState: Bool) {
        delegates.add(delegate)
        performOnMain { [weak self] in self?.startObserving() }
        guard replayCurrentState else { return }
        // Preserve deferred startup: the consumer finishes construction before catch-up can resolve peers.
        performOn(.main) { [weak self, weak delegate] in
            guard let self, let delegate, self.delegates.contains(delegate),
                  self.applicationState() == .active else { return }
            delegate.onAppActive()
        }
    }

    /// Remove synchronously, including during deinit or before queued startup catch-up executes.
    func removeDelegate(_ delegate: LifecycleDelegate) {
        delegates.remove(delegate)
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        observe(UIApplication.didBecomeActiveNotification) { $0.onAppActive() }
        observe(UIApplication.didEnterBackgroundNotification) { $0.onAppBackground() }
        observe(UIScene.didActivateNotification) { $0.onSceneActive() }
        observe(UIWindow.didBecomeKeyNotification) { $0.onWindowBecameKey() }
        observe(UIApplication.didReceiveMemoryWarningNotification) { $0.onMemoryWarning() }
        observers.append(notificationCenter.addObserver(
            forName: UIScene.didDisconnectNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let scene = notification.object as? UIScene else { return }
            self?.broadcast { $0.onSceneDisconnected(scene) }
        })
    }

    private func observe(_ name: Notification.Name, callback: @escaping (LifecycleDelegate) -> Void) {
        observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            self?.broadcast(callback)
        })
    }

    private func broadcast(_ callback: (LifecycleDelegate) -> Void) {
        // A prior delegate can remove another one during delivery. Do not call a retired subscriber.
        delegates.invoke { if delegates.contains($0) { callback($0) } }
    }
}
