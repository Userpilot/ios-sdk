//
//  AutoPropertyDecorator.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 10/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
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
    func start()
}

/// A concrete implementation of `SessionMonitoring` that monitors app lifecycle changes
/// and interacts with an analytics publisher to flush or resume analytics connection state.
/// - `SessionMonitor` listens for app background and foreground transitions and triggers analytics
/// operations accordingly.
internal class SessionMonitor: SessionMonitoring {

    /// The analytics publisher responsible for flushing and resuming events.
    private let analyticsPublisher: AnalyticsPublishing

    /// Initializes the `SessionMonitor` with a dependency container that resolves an `AnalyticsPublishing` instance.
    /// - Parameter container: The dependency injection container used to resolve the required dependencies.
    init(container: DIContainer) {
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
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

    /// Called when the app enters the background.
    /// This method flushes any pending analytics events.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterBackground(notification: Notification) {
        analyticsPublisher.flush()
    }

    /// Called when the app enters the foreground.
    /// This method resumes analytics sockect connection and event publishing.
    /// - Parameter notification: The notification object containing information about the event.
    @objc
    func didEnterForeground(notification: Notification) {
        analyticsPublisher.resume()
    }
}
