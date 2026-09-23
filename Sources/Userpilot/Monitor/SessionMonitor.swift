//
//  AutoPropertyDecorator.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 10/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `SessionMonitor` class provides automatic app lifecycle tracking to handle flushing events.
//

import Foundation
import UIKit

/**
Protocol defining session monitoring behavior.
Objects that conform to `SessionMonitoring` are expected to handle lifecycle events such as
app entering the background or foreground.
 */
internal protocol SessionMonitoring: AnyObject {
    /// Starts the session monitoring process, setting up observers for app lifecycle events.
    func reset()

    /// A flag to mintor app status
    var isAppActive: Bool { get }
}

internal class SessionMonitor: SessionMonitoring {

    /// The analytics publisher responsible for flushing and resuming events.
    private let analyticsPublisher: AnalyticsPublishing

    /// Network monitor to pause/resume on lifecycle changes.
    private let networkMonitor: NetworkMonitoring

    /// The storage used to store user-related data.
    private let storage: DataStoring

    /// A flag to mintor app status.
    /// Written on the main thread by the lifecycle callbacks, read from the socket and
    /// analytics queues (`SocketManager.publish`, `AnalyticsPublisher.publish`) to drop
    /// events while the app is inactive. Unguarded, a reader can miss the background
    /// transition and push events over a socket the system is about to suspend.
    private let _isAppActive = AtomicReference<Bool>(true)

    /// Whether `onAppStart()` has run for the current foreground period.
    /// Set on the main thread by `onAppStart()` and `didEnterBackground`, but also cleared by
    /// `reset()`, which `deinit` calls on whichever thread releases the last reference — so
    /// this cannot be a plain `Bool`.
    private let hasStartedSession = AtomicReference<Bool>(false)

    /// Initializes the `SessionMonitor` with a dependency container that resolves an `AnalyticsPublishing` instance.
    /// - Parameter container: The dependency injection container used to resolve the required dependencies.
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.networkMonitor = container.resolve(NetworkMonitoring.self)
        self.storage = container.resolve(DataStoring.self)

        // Add observer for when the app enters the background.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        // Add observer for every transition to the active state.
        // `didBecomeActive` supersedes `willEnterForeground`: it covers the first
        // activation (which `willEnterForeground` never delivers — that one only fires
        // when returning from background) *and* every later foreground return, so a
        // single observer handles both. Wrapper SDKs (Capacitor / Flutter / React Native
        // / MAUI) build `Userpilot` while UIKit is still `.inactive`, so with
        // `willEnterForeground` alone `resume()` never ran and the socket stayed closed
        // until the user backgrounded and foregrounded the app.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // The one activation no notification can deliver: the SDK was created *after*
        // the app was already `.active`, so `didBecomeActive` has already fired and will
        // not fire again until the next activation. Catch up on the current state.
        DispatchQueue.main.async { [weak self] in
            guard let self, UIApplication.shared.applicationState == .active else { return }
            self.onAppStart()
        }
    }

    /// remove notification observer
    deinit {
        reset()
    }

    /// Logic to check if the socket is currently open
    var isAppActive: Bool {
        _isAppActive.value
    }

    func reset() {
        // Stop listening for further lifecycle callbacks
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

        hasStartedSession.value = false

        // Clean up state we previously persisted
        storage.sessionDate = nil
    }

    /// Called when the app enters the background.
    /// This method flushes any pending analytics events.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterBackground(notification: Notification) {
        hasStartedSession.value = false
        _isAppActive.value = false
        storage.sessionDate = Date()
        networkMonitor.stopMonitoring()
        analyticsPublisher.flush()
    }

    /// Called when the app becomes active — cold start and every foreground return.
    /// This method resumes analytics socket connection and event publishing.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didBecomeActive(notification: Notification) {
        onAppStart()
    }

    /// Resumes monitoring and publishing once per foreground period. Deduplicates the
    /// init catch-up and `didBecomeActive` (which can both fire for the same activation),
    /// and `.inactive` → `.active` bounces (Control Center, alerts) that never backgrounded.
    private func onAppStart() {
        // Claim the foreground period in one atomic step - a separate read then write would
        // let two activations both pass the check and resume twice.
        guard hasStartedSession.compareAndSet(expected: false, new: true) else { return }

        _isAppActive.value = true
        networkMonitor.startMonitoring()
        analyticsPublisher.resume()
    }

}
