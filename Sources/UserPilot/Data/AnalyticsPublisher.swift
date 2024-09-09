//
//  AnalyticsPublishing.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `AnalyticsPublisher` handles the processing and dispatching of events to the backend.
//  It manages event lifecycle, queuing, and socket communication for sending events
//  such as `identify`, `screen`, and custom user events.
//

// swiftlint:disable file_length
import Foundation

/**
 The `AnalyticsPublishing` protocol defines the methods necessary
 to publish analytic events and manage the event lifecycle.
 
 - Methods:
   - `publish(_:)`: Sends an event to the backend.
   - `clean()`: Clears any cached events or session data.
 */
internal protocol AnalyticsPublishing: AnyObject {
    func publish(_ event: Event)
    func clean()
}

/**
 The `AnalyticsPublisher` class implements the `AnalyticsPublishing` protocol
 to process events and send them to the backend.
 
 It handles socket connections, event caching, and ensures events are sent
 reliably. The class supports tracking user identification, screen views, and
 custom events, with event queuing and debouncing to optimize network traffic.
 */
internal class AnalyticsPublisher {

    // MARK: - Properties

    /// Weak reference to the owning `UserPilot` instance.
    private weak var userPilot: UserPilot?

    /// SDK logger.
    private let logger: Logging

    /// The storage used to store user-related data.
    private let storage: DataStoring

    /// Decorator used to modify event properties before sending.
    private let autoPropertyDecorator: AutoPropertyDecoratoring

    /// Manages socket connections and event publishing over websockets.
    private let socketManager: SocketEvents

    /// Queue to hold events waiting to be sent.
    private lazy var eventsToFlush = [TrackedPayloadEvent]()

    /// A debouncer used to control the frequency of event flushing.
    /// let backgroundQueue = DispatchQueue(label: "com.example.background")
    /// let debouncer = Debouncer(delay: 1.0, queue: backgroundQueue)
    private var debouncer = Debouncer(delay: 3.0)

    /// Read-write lock for thread-safe event queue operations.
    private lazy var readWriteLock = ReadWriteLock(label: DispatchQueueConstants.EVENT_QUEUE)

    /// Cached identify event, to be sent when the socket is ready.
    private var cachedIdentifyEvent: Event?

    /// Tracks the last screen viewed and whether it was processed.
    private var lastScreenViewed: (Bool, Event)?

    /// Tracks the first event to open the socket.
    private var cachedEvent: Event?

    /// Counter for events sent during the current session.
    private var eventsCount = 0

    /// Set of event names sent during the current screen view.
    private var eventsName = Set<String>()

    // MARK: - Initialization

    /**
     Initializes the `AnalyticsPublisher` with dependencies from the provided dependency injection container.
     
     - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.userPilot = container.owner
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.socketManager = container.resolve(SocketEvents.self)
        self.logger = container.resolve(UserPilot.Config.self).logger

        // Register socket event callback
        self.socketManager.registerCallback(self)
    }

}

// MARK: - AnalyticsPublishing

extension AnalyticsPublisher: AnalyticsPublishing {

    /**
     Logs the event details once it has been sent through the socket.
     
     - Parameter event: The event to log.
     */
    func logEvent(_ event: Event) {
        guard let logger = userPilot?.config.logger else { return }
        event.logData(logger: logger)
    }

    /**
     Clears last screen viewed and pending events in the queue.
     
     This method comes when switch to new Identify userID, should clean all cached events for old user
     and clear screen last screen viewed
     */
    func clean() {
        clearCachedEvents()
        clearLastScreenViewedEvent()
    }

    /**
     Publishes an event to the backend based on its type (identify, screen, or custom event).
     
     - Parameter event: The event to publish.
     */
    func publish(_ event: Event) {
        switch event.type {
        case .identify:
            identify(event)
        case .screen:
            screen(event)
        case .event:
            trackEvent(event)
        }
    }

    // MARK: - Event Handling

    /**
     Identifies the user and handles the `identify` event.
     
     - If the user ID has changed, it resets the socket connection and caches the new event.
     - If the socket is open, the event is sent immediately; otherwise, it waits for the socket to connect.
     
     - Parameter event: The `identify` event to process.
     */
    private func identify(_ event: Event) {
        guard let userID = event.type.userID else { return }

        cachedIdentifyEvent = event

        /// In-case the user call identify event directly after identify calls
        if socketManager.isJoiningSocket {
            return
        }

        /// In-case new user ID
        if socketManager.isSocketOpened && storage.userID.isNotEmpty && userID != storage.userID {
            userPilot?.clean()
            closeSocket()
            return
        }

        /// In-case new session
        storage.userID = userID

        if socketManager.isSocketOpened {
            flushEvent()
        } else {
            openSocket()
        }
    }

    /**
     Processes and sends screen view events.
     
     - Ensures that the socket is open and the screen has not been previously viewed.
     - Resets the event count for a new screen view.
     
     - Parameter event: The screen event to process.
     */
    private func screen(_ event: Event) {
        /// In-case the user call screen event directly after identify
        if socketManager.isJoiningSocket {
            lastScreenViewed = (false, event)
            return
        }

        /// In-case first event called screen in the new session
        if !socketManager.isSocketOpened && socketManager.isAllowToOpenSocket {
            openSocket()
            return
        }

        guard
            socketManager.isSocketOpened &&
            (lastScreenViewed == nil ||
            lastScreenViewed?.1.type.screenName != event.type.screenName)
        else { return }

        eventsCount = 0
        lastScreenViewed = (false, event)
        flushEvent()
    }

    /**
     Tracks and sends custom user events.
     
     - Ensures the event count and uniqueness constraints are met before publishing.
     
     - Parameter event: The custom event to process.
     */
    private func trackEvent(_ event: Event) {
        /// In-case first event called is event in the new session
        if !socketManager.isSocketOpened && socketManager.isAllowToOpenSocket {
            cachedEvent = event
            openSocket()
            return
        }

        guard
            socketManager.isSocketOpened,
            !eventsName.contains(event.type.eventName),
            eventsCount < GeneralConstants.MAX_EVENTS_PER_SCREEN
        else { return }

        eventsCount.increment()
        eventsName.insert(event.type.eventName)
        readWriteLock.write {
            self.debouncer.cancel()
            self.eventsToFlush.append(TrackedPayloadEvent(title: event.type.eventName, meta: event.properties))
            self.flushQueue()
        }
    }
}

// MARK: - SocketSubscription

extension AnalyticsPublisher {

    /**
     Flushes high-priority events, such as identify or screen events, through the socket, or events that
     opens the socket.
     
     - Parameter event: The event to flush.
     */
    private func flushEvent() {
        var payload: [String: Any] = [:]

        /// Identify event
        if let identifyEvent = cachedIdentifyEvent {

            // In-case identify event called again when joining socket channel
            if identifyEvent.userID != storage.userID {
                identify(identifyEvent)
                return
            }
            self.logger.info("USER %{punlic}@", "\(identifyEvent.userID)")
            if let properties = identifyEvent.properties {
                payload[AnalyticsPublisher.identifyMetaDataProperty] = properties
            }
            if let company = identifyEvent.company {
                payload[AnalyticsPublisher.identifyCompanyProperty] = company
            }
            clearCachedIdentifyEvent()
            socketManager.publish(identifyEvent.type.eventName, payload: payload)
        }

        /// Screen event
        if let screenEvent = lastScreenViewed, screenEvent.0 == false {
            self.logger.info("SCREEN %{punlic}@", "\(screenEvent.1.type.screenName)")
            payload[AnalyticsPublisher.identifyScreenProperty] = screenEvent.1.type.screenName
            socketManager.publish(screenEvent.1.type.eventName, payload: payload)
        }

        /// Track event
        if let event = cachedEvent {
            clearCachedEvent()
            self.eventsToFlush.append(TrackedPayloadEvent(title: event.type.eventName, meta: event.properties))
            flushQueue()
        }
    }

    /**
     Flushes the queue of normal events, applying debouncing logic to prevent excessive socket communication.
     */
    private func flushQueue() {
        /// Debouncer
        debouncer.debounce { [weak self] in
            guard let self = self else { return }

            // Read write lock
            readWriteLock.read {
                if self.eventsToFlush.isEmpty { return }
//                self.logger.info("AnalyticsPublisher events size %{punlic}@", "\(self.eventsToFlush.count)")
                let compyItems = self.eventsToFlush
//                compyItems.forEach {
//                    self.logger.info("Event name: %{punlic}@", $0.title)
//                }
                /// clear cached properties, publish events
                self.eventsToFlush.removeAll()
                self.eventsName.removeAll()
                self.socketManager.publish(
                    EventNameConstants.EVENT,
                    payload: TrackedPayload(events: compyItems).toDictionary())
            }
        }
    }

}

// MARK: - Socket Management

extension AnalyticsPublisher: SocketSubscription {

    /// Opens the socket and sends the event once the connection is established on callback.
    private func openSocket() {
        socketManager.connect()
    }

    /// Closes the socket when a new user is identified, then reopens the socket for the new user on callback.
    private func closeSocket() {
        socketManager.close()
    }

    /// Socket opened callback.
    func onSocketOpened() {
        clearCachedEvents()
        flushEvent()
    }

    /// Socket closed callback
    func onSocketClosed() {
        if let eventToPublish = cachedIdentifyEvent {
            identify(eventToPublish)
        } else {
            clearAllCachedProperties()
        }
    }

    /**
     Callback method triggered when a socket event has been sent, ensuring any remaining queued events are flushed.
     
     - Parameters:
       - eventName: The name of the event sent.
       - eventSent: Whether the event was successfully sent.
     */
    func onSocketEventSent(_ eventName: String, _ eventSent: Bool) {
        flushQueue()
    }

}

// MARK: - Reset cached properties

private extension AnalyticsPublisher {

    /// Clear all cached properties in case we get closed callback from socket.
    private func clearAllCachedProperties() {
        clearCachedEvents()
        clearCachedIdentifyEvent()
        clearLastScreenViewedEvent()
        clearCachedEvent()
    }

    /// Clears the cached events on new identify event or when socket opened.
    private func clearCachedEvents() {
        eventsToFlush.removeAll()
        debouncer.cancel()
    }

    /// Clears the cached identify event after it has been successfully sent.
    private func clearCachedIdentifyEvent() {
        cachedIdentifyEvent = nil
    }

    /// Clears the cached last screen viewed on new identify event.
    private func clearLastScreenViewedEvent() {
        lastScreenViewed = nil
    }

    /// Clears the cached identify event after it has been successfully sent.
    private func clearCachedEvent() {
        cachedEvent = nil
    }

}

// MARK: - Properties name

private extension AnalyticsPublisher {

    // Static constants
    static var identifyMetaDataProperty: String { return "metadata" }
    static var identifyCompanyProperty: String { return "company" }

    static var identifyScreenProperty: String { return "title" }
}
