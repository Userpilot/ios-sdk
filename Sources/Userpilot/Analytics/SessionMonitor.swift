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
}

internal class SessionMonitor: SessionMonitoring, BootUp {

    /// The analytics publisher responsible for flushing and resuming events.
    private let analyticsPublisher: AnalyticsPublishing

    /// The storage used to store user-related data.
    private var storage: DataStoring

    /// Initializes the `SessionMonitor` with a dependency container that resolves an `AnalyticsPublishing` instance.
    /// - Parameter container: The dependency injection container used to resolve the required dependencies.
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.storage = container.resolve(DataStoring.self)
    }

    /// Starts monitoring app lifecycle changes by observing `UIApplication` notifications for
    /// background and foreground transitions.
    func start() {
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
    }

    func reset() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    /// Called when the app enters the background.
    /// This method flushes any pending analytics events.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterBackground(notification: Notification) {
        storage.sessionDate = Date()
        analyticsPublisher.flush()
    }

    /// Called when the app enters the foreground.
    /// This method resumes analytics socket connection and event publishing.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterForeground(notification: Notification) {
        analyticsPublisher.resume()
    }
}
