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

/// Protocol defining session monitoring behavior.
/// Objects that conform to `SessionMonitoring` are expected to handle lifecycle events such as
/// app entering the background or foreground.
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

    /// Screen time tracker for foreground-only time per screen.
    private let screenTimeTracker: ScreenTimeTracking

    /// A flag to prevent calling didEnterForeground twice
    private var hasInitializedForeground = false

    /// A flag to mintor app status
    private var _isAppActive = true

    /// Initializes the `SessionMonitor` with a dependency container that resolves an `AnalyticsPublishing` instance.
    /// - Parameter container: The dependency injection container used to resolve the required dependencies.
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.networkMonitor = container.resolve(NetworkMonitoring.self)
        self.storage = container.resolve(DataStoring.self)
        self.screenTimeTracker = container.resolve(ScreenTimeTracking.self)

        // Add observer for when the app enters the background.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        // Add observer for when the app enters the foreground.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Handle initial state only if app is currently active
        // This is a common issue when using native iOS SDKs within Flutter or ReactNative plugins.
        // The problem occurs due to the different lifecycle management between
        // these plugins and native iOS apps.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if UIApplication.shared.applicationState == .active && !self.hasInitializedForeground {
                self.onAppStart()
            }
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
        hasInitializedForeground = false

        // Stop listening for further lifecycle callbacks
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
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
        screenTimeTracker.onAppBackground()
        storage.sessionDate = Date()
        networkMonitor.stopMonitoring()
        analyticsPublisher.flush()
    }

    /// Called when the app enters the foreground.
    /// This method resumes analytics socket connection and event publishing.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterForeground(notification: Notification) {
        onAppStart()
    }

    private func onAppStart() {
        _isAppActive = true
        hasInitializedForeground = true
        screenTimeTracker.onAppForeground()
        networkMonitor.startMonitoring()
        analyticsPublisher.resume()
    }
}
