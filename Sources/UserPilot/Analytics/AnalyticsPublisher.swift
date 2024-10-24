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
import SwiftPhoenixClient

/**
 The `AnalyticsPublishing` protocol defines the methods necessary
 to publish analytic events and manage the event lifecycle.
 
 - Methods:
 - `publish(_:)`: Sends an event to the backend.
 - `clean()`: Clears any cached events or session data.
 - `flush()`: Flushs any cached events or session data.
 - `resume()`: Open socket connection.
 */
internal protocol AnalyticsPublishing: AnyObject {
    func publish(_ event: Event)
    func flush()
    func resume()
    func logout(socketState: SocketManager.SocketState, shouldClearCachedIdentifyEvent: Bool)
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
    private var storage: DataStoring

    /// Decorator used to modify event properties before sending.
    private let autoPropertyDecorator: AutoPropertyDecoratoring

    /// Manages socket connections and event publishing over websockets.
    private let socketManager: SocketEvents

    /// Queue to hold events waiting to be sent.
    private lazy var eventsToFlush = [Event]()

    /// Set of event names sent during the current screen view.
    private var eventsName = Set<String>()

    /// A debouncer used to control the frequency of event flushing.
    /// let backgroundQueue = DispatchQueue(label: "com.example.background")
    /// let debouncer = Debouncer(delay: 1.0, queue: backgroundQueue)
    private var debouncer = Debouncer(delay: 2.0)

    /// Read-write lock for thread-safe event queue operations.
    private lazy var readWriteLock = ReadWriteLock(label: DispatchQueueConstants.EVENT_QUEUE)

    /// Cached identify event, to be sent when the socket is ready.
    private var cachedIdentifyEvent: Event?

    /// Tracks the last screen viewed and whether it was processed.
    private var lastScreenViewed: (Bool, Event)?

    /// Tracks the first event to open the socket.
    private var cachedEvent: Event?

    /// Counter for events per screen.
    private var eventsCount = 0

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
        if let temporaryUserString = storage.temporaryUser {
            let temporaryUser = User.fromJson(temporaryUserString) // temporaryUserString.toUser()
            cachedIdentifyEvent = Event(type: EventType.identify(temporaryUser.userID),
                                properties: temporaryUser.properties,
                                company: temporaryUser.company)
        }
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
     Flush the event once the app enter background.
     */
    func flush() {
        socketManager.updateSocketState(.shuttingDown)
        debouncer.cancel()
        flushQueue(shouldCloseSocket: true, flushImmediately: true)
    }

    /**
     Clear all cached data and close the socket.
     */
    func logout(socketState: SocketManager.SocketState, shouldClearCachedIdentifyEvent: Bool = false) {
        socketManager.updateSocketState(socketState)
        clearAllCachedProperties(shouldClearCachedIdentifyEvent)
        socketManager.close()
    }

    /**
     Resume socket connection when back from background.
     */
    func resume() {
        if let userID = cachedIdentifyEvent?.userID {
            storage.userID = userID
        }
        if storage.userID.isNotEmpty && !socketManager.isSocketOpened && !socketManager.isJoiningSocket {
            socketManager.connect()
        }
    }

    /**
     Publishes an event to the backend based on its type (identify, screen, or custom event).
     
     - Parameter event: The event to publish.
     */
    func publish(_ event: Event) {
        if event.isIdentifyEvent {
            storage.temporaryUser = event.toUser().toJson()
            cachedIdentifyEvent = event
            socketManager.updateSocketState(.closed)
        }
        if socketManager.isShutdownState { return }
        if socketManager.isJoiningSocket {
            cacheEvent(event)
            return
        }

        if !socketManager.isSocketOpened {
            cacheEvent(event)
            if let userID = cachedIdentifyEvent?.userID { storage.userID = userID }
            if let userID = event.userID { storage.userID = userID }
            if storage.userID.isEmpty { return }
            openSocket()
            return
        }

        switch event.type {
        case .identify:
            identify(event)
        case .screen:
            screen(event)
        case .event:
            trackEvent(event)
        }
    }

    /**
     Cache Event when socket is not opened or is joining.
     
     - Parameter event: The event to publish.
     */
    private func cacheEvent(_ event: Event) {
        switch event.type {
        case .identify:
            cachedIdentifyEvent = event
        case .screen:
            lastScreenViewed = (false, event)
        case .event:
            cachedEvent = event
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
        guard let userID = event.userID else { return }

        /// In-case new user ID
        if storage.userID.isNotEmpty && userID != storage.userID {
            userPilot?.clean()
            logout(socketState: .switchingUser)
        } else {
            // In-case new user ID
            if User.fromJson(storage.user).isSameIdentifyEvent(event: event) { return }
            flushPriorityEvents()
        }
    }

    /**
     Processes and sends screen view events.
     
     - Ensures that the socket is open and the screen has not been previously viewed.
     - Resets the event count for a new screen view.
     
     - Parameter event: The screen event to process.
     */
    private func screen(_ event: Event) {
        guard
            lastScreenViewed == nil ||
                lastScreenViewed?.1.screenTitle != event.screenTitle
        else { return }

        eventsCount = 0
        lastScreenViewed = (false, event)
        flushPriorityEvents()
    }

    /**
     Tracks general user events.
     
     - Ensures the event count and uniqueness constraints are met before publishing.
     
     - Parameter event: The event to track.
     */
    private func trackEvent(_ event: Event) {
        readWriteLock.write { [weak self] in
            guard let self = self else { return }
            guard
                !eventsName.contains(event.eventTitle),
                eventsCount < GeneralConstants.MAX_EVENTS_PER_SCREEN
            else { return }

            eventsCount.increment()
            eventsName.insert(event.eventTitle)

            self.debouncer.cancel()
            self.eventsToFlush.append(event)
            self.flushTrackedEvents()
        }
    }
}

// MARK: - SocketSubscription

extension AnalyticsPublisher {

    /**
     Flushes high-priority events, such as identify or screen events, through the socket, or events that
     opens the socket.
     */
    private func flushPriorityEvents() {
        if !socketManager.isSocketOpened || socketManager.isJoiningSocket { return }

        /// Identify event
        if let identifyEvent = cachedIdentifyEvent {
            var payload: [String: Any] = [:]
            guard let userID = identifyEvent.userID else { return }
            // In-case identify event called again when joining socket channel
            if storage.userID.isNotEmpty && userID != storage.userID {
                identify(identifyEvent)
                return
            }
            payload[AnalyticsPublisher.metaDataProperty] = identifyEvent.properties ?? [:]
            if let company = identifyEvent.company, !company.isEmpty {
                payload[AnalyticsPublisher.identifyCompanyProperty] = company
            }
            socketManager.publish(identifyEvent.eventName, payload: payload)
        }

        /// Screen event
        if let screenEvent = lastScreenViewed, screenEvent.0 == false {
            var payload: [String: Any] = [:]
            payload[AnalyticsPublisher.identifyScreenProperty] = screenEvent.1.screenTitle
            socketManager.publish(screenEvent.1.eventName, payload: payload)
        }

        /// Track event
        if let event = cachedEvent {
            clearCachedEvent()
            self.eventsToFlush.append(event)
            flushTrackedEvents()
        }
    }

    /**
     Flushes the queue of normal events, applying debouncing logic to prevent excessive socket communication.
     */
    private func flushTrackedEvents() {
        debouncer.debounce { [weak self] in
            self?.flushQueue()
        }
    }

    /**
     Flushs the queue directly, for example when application moves to background
     */
    private func flushQueue(shouldCloseSocket: Bool = false, flushImmediately: Bool = false) {
        readWriteLock.read {
            if !socketManager.isSocketOpened || socketManager.isJoiningSocket { return }
            if self.eventsToFlush.isEmpty {
                if shouldCloseSocket { closeSocket() }
                return
            }

            if let eventToSend = self.eventsToFlush.first {
                eventsToFlush.removeFirst()
                eventsName.remove(eventToSend.eventTitle)

                var payload: [String: Any] = [:]
                payload[AnalyticsPublisher.eventNameProperty] = eventToSend.eventTitle
                payload[AnalyticsPublisher.metaDataProperty] = eventToSend.properties ?? [:]

                socketManager.publish(
                    eventToSend.eventName,
                    payload: payload,
                    shouldCloseSocket: shouldCloseSocket
                )

                if flushImmediately {
                    flushQueue(shouldCloseSocket: shouldCloseSocket, flushImmediately: true)
                } else {
                    if !shouldCloseSocket {
                        flushTrackedEvents()
                    }
                }
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
        flushPriorityEvents()
    }

    /// Socket closed callback.
    func onSocketClosed() {
        if socketManager.didErrorOccurred {
            clearAllCachedProperties()
            return
        }
        if let eventToPublish = cachedIdentifyEvent {
            userPilot?.clean()
            publish(eventToPublish)
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
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        if let cachedIdentifyEvent {
            if eventName == EventType.identifyEvent &&
                cachedIdentifyEvent.userID == storage.userID {
                var newUser = User.fromJson(storage.user)
                storage.user = newUser.updateUser(event: cachedIdentifyEvent).toJson() ?? ""
                self.logger.info("👤 USER %{public}@", storage.user)
                clearCachedIdentifyEvent()
            }
        }
        flushTrackedEvents()
    }

}

// MARK: - Reset cached properties

private extension AnalyticsPublisher {

    /// Clear all cached properties in case we get closed callback from socket.
    private func clearAllCachedProperties(_ shouldClearCachedIdentifyEvent: Bool = false) {
        clearCachedEvents()
        clearLastScreenViewedEvent()
        clearCachedEvent()
        if shouldClearCachedIdentifyEvent { clearCachedIdentifyEvent() }
    }

    /// Clears the cached events on new identify event or when socket opened.
    private func clearCachedEvents() {
        eventsToFlush.removeAll()
        debouncer.cancel()
    }

    /// Clears the cached identify event after it has been successfully sent.
    private func clearCachedIdentifyEvent() {
        cachedIdentifyEvent = nil
        storage.temporaryUser = nil
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

internal extension AnalyticsPublisher {

    // Static constants
    static var metaDataProperty: String { return "metadata" }
    static var identifyCompanyProperty: String { return "company" }

    static var identifyScreenProperty: String { return "title" }
    static var eventNameProperty = "event_name"
}
