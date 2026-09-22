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

    /// A flag to mintor app status
    private var _isAppActive = true

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
        _isAppActive
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

        // Clean up state we previously persisted
        storage.sessionDate = nil
    }

    /// Called when the app enters the background.
    /// This method flushes any pending analytics events.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterBackground(notification: Notification) {
        _isAppActive = false
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

    /// Resumes monitoring and publishing. Safe to call repeatedly: `startMonitoring()`
    /// returns early while a path monitor is alive, `resume()` no-ops without a stored
    /// session date, and `connect()` gates on the socket state — so no guard flag is
    /// needed to dedupe the activation paths.
    private func onAppStart() {
        _isAppActive = true
        networkMonitor.startMonitoring()
        analyticsPublisher.resume()
    }

}
