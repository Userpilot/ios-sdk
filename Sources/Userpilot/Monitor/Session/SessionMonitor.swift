//
//  SessionMonitor.swift
//  Userpilot SDK
//
//  Created by Userpilot on 10/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  The `SessionMonitor` class provides automatic app lifecycle tracking to handle flushing events.
//

import Foundation

/**
Protocol defining session monitoring behavior.
Objects that conform to `SessionMonitoring` are expected to handle lifecycle events such as
app entering the background or foreground.
 */
internal protocol SessionMonitoring: AnyObject {
    /// Removes lifecycle observers and clears the stored background timestamp.
    func reset()

    /// Whether analytics may publish during the current foreground period.
    var isAppActive: Bool { get }
}

/// Owns this instance's session lifecycle: publishing eligibility, connectivity and analytics ordering.
/// Native callbacks run on main; the atomic activity snapshot is safe for analytics/socket workers.
internal final class SessionMonitor: SessionMonitoring, LifecycleDelegate {

    // Dependencies
    private let analyticsPublisher: AnalyticsPublishing
    private let networkMonitor: NetworkMonitoring
    private let storage: DataStoring
    private let lifecycleMonitor: LifecycleMonitoring

    /// Update before network callbacks or analytics work can read publishing eligibility.
    private let appActive = AtomicReference<Bool>(true)

    /// Whether `onAppStart()` has run for the current foreground period.
    /// Set on the main thread by `onAppStart()` and `onAppBackground`, but also cleared by
    /// `reset()`, which `deinit` calls on whichever thread releases the last reference — so
    /// this cannot be a plain `Bool`.
    private let hasStartedSession = AtomicReference<Bool>(false)

    /// Initializes the `SessionMonitor` with a dependency container that resolves an `AnalyticsPublishing` instance.
    /// - Parameter container: The dependency injection container used to resolve the required dependencies.
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.networkMonitor = container.resolve(NetworkMonitoring.self)
        self.storage = container.resolve(DataStoring.self)
        self.lifecycleMonitor = container.resolve(LifecycleMonitoring.self)

        // The shared observer includes cold-start activation and foreground returns. Catch-up stays
        // queued so this instance can finish constructing before analytics resumes. The per-session
        // latch below deduplicates catch-up and a notification delivered for the same activation.
        lifecycleMonitor.addDelegate(self, replayCurrentState: true)
    }

    /// remove notification observer
    deinit {
        reset()
    }

    /// Reads app activity independently of whether the socket is connected.
    var isAppActive: Bool {
        appActive.value
    }

    func reset() {
        lifecycleMonitor.removeDelegate(self)

        hasStartedSession.value = false

        // Clean up state we previously persisted
        storage.sessionDate = nil
    }

    /// Called when the app enters the background.
    /// This method flushes any pending analytics events.
    func onAppBackground() {
        hasStartedSession.value = false
        appActive.value = false
        storage.sessionDate = Date()
        networkMonitor.stopMonitoring()
        analyticsPublisher.flush()
    }

    /// Called when the app becomes active — cold start and every foreground return.
    /// This method resumes analytics socket connection and event publishing.
    func onAppActive() {
        onAppStart()
    }

    /// Starts connectivity before resuming analytics, once per foreground period. Deduplicates the
    /// init catch-up and `onAppActive` (which can both fire for the same activation),
    /// and `.inactive` → `.active` bounces (Control Center, alerts) that never backgrounded.
    private func onAppStart() {
        // Claim the foreground period in one atomic step - a separate read then write would
        // let two activations both pass the check and resume twice.
        guard hasStartedSession.compareAndSet(expected: false, new: true) else { return }

        appActive.value = true
        networkMonitor.startMonitoring()
        analyticsPublisher.resume()
    }

}
