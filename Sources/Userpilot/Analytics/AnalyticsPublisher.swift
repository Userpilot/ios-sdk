//
//  AnalyticsPublishing.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
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
 */
internal protocol AnalyticsPublishing: AnyObject {
    /// Sends an event to the backend.
    func publish(_ event: Event)

    /// Flush any cached events or session data.
    func flush()

    /// Open socket connection.
    func resume()

    /// Reset state
    func reset()

    /// Logout user from socket
    func logout(socketState: SocketManager.SocketState,
                shouldClearCachedIdentifyEvent: Bool)

    /// check socket state
    var canRequestEvent: Bool { get }

    /// publish experience event
    func publishExperienceEvent(_ sdkEvent: SDKEvent, isExpereinceEvent: Bool, socketSubscription: SocketSubscription)

    /// publish fake reload event
    func publishFakeReloadScreenEvent()

    /// update seen experiences
    func experiencePublished(_ experienceId: Int)

    /// For experience which are come from start session
    var isStartSession: Bool { get }
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

    // A weak reference to ExperienceRendering would be expected here to avoid a retain cycle with AnalyticsPublisher
    private weak var container: DIContainer?

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?

    /// SDK logger.
    private let logger: Logging

    /// The storage used to store user-related data.
    private var storage: DataStoring

    /// The experience publisher.
    private lazy var experiencesPublisher: ExperiencesPublishing? = {
        container?.resolve(ExperiencesPublishing.self)
    }()

    /// Decorator used to modify event properties before sending.
    private let autoPropertyDecorator: AutoPropertyDecoratoring

    /// Manages socket connections and event publishing over web socket.
    private let socketManager: SocketEvents

    /// Queue to hold events waiting to be sent.
    private lazy var eventsToFlush = [Event]()

    /// Set of event names sent during the current screen view.
    private var eventsName = Set<String>()

    /// EventThrottle to throttle events
    private let eventThrottle = EventThrottle(throttleDuration: 1.0)

    /// Read-write lock for thread-safe event queue operations.
    private lazy var readWriteLock = ReadWriteLock(label: DispatchQueueConstants.EVENT_QUEUE)

    /// Cached identify event, to be sent when the socket is ready.
    private var cachedIdentifyEvent: Event?

    /// Tracks the last screen viewed, bool for fake reload state.
    private var screenViewEntity: ScreenViewEntity?

    /// Tracks the first event to open the socket.
    private var cachedEvent: Event?

    /// Hole session start state
    private var startSession = true

    // MARK: - Initialization

    /**
     Initializes the `AnalyticsPublisher` with dependencies from the provided dependency injection container.
     
     - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.container = container
        self.userpilot = container.owner
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.socketManager = container.resolve(SocketEvents.self)
        self.logger = container.resolve(Userpilot.Config.self).logger

        // Register socket event callback
        self.socketManager.registerCallback(self)
        if let temporaryUserString = storage.temporaryUser {
            let temporaryUser = User.fromJson(temporaryUserString)
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
        guard let logger = userpilot?.config.logger else { return }
        event.logData(logger: logger)
    }

    /**
     Flush the event once the app enter background.
     */
    func flush() {
        socketManager.updateSocketState(.shuttingDown, forceUpdateState: true)
        flushQueue(shouldCloseSocket: true, flushImmediately: true)
    }

    /**
     Clear all cached data and close the socket.
     */
    func logout(socketState: SocketManager.SocketState, shouldClearCachedIdentifyEvent: Bool = false) {
        startSession = true
        screenViewEntity?.resetState()
        socketManager.updateSocketState(socketState, forceUpdateState: true)
        clearAllCachedProperties(shouldClearCachedIdentifyEvent)
        socketManager.close()
    }

    /**
     Resume socket connection when back from background.
     */
    func resume() {
        updateSessionState()
        if let userID = cachedIdentifyEvent?.userID {
            storage.userID = userID
        }
        if storage.userID.isNotEmpty && !socketManager.isSocketOpened && !socketManager.isJoiningSocket {
            socketManager.connect()
        }
    }

    /**
     Reset session state
     */
    func reset() {
        startSession = true
        eventThrottle.clear()
    }

    /**
     Compare the saved date with the current date and return true if the difference is more than 30 minutes
     */
    func updateSessionState() {
        guard let sessionDate = storage.sessionDate else { return }
        storage.sessionDate = nil
        let difference = Date().timeIntervalSince(sessionDate)
        startSession = difference > GeneralConstants.SESSION_DURATION
    }

    /*
     Publishes an event to the backend based on its type (identify, screen, or custom event).
     
     - Parameter event: The event to publish.
     */
    // swiftlint:disable:next cyclomatic_complexity
    func publish(_ event: Event) {
        tryCatch {
            if event.isIdentifyEvent {
                if storage.user.isNotEmpty && User.fromJson(storage.user).isSameIdentifyEvent(event: event) { return }
                screenViewEntity?.resetState()
                storage.temporaryUser = event.toUser().toJson()
                cachedIdentifyEvent = event
                socketManager.updateSocketState(.closed, forceUpdateState: true)
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
            setupScreenEvent(event)
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
        tryCatch {
            guard let userID = event.userID else { return }

            /// In-case new user ID
            if storage.userID.isNotEmpty && userID != storage.userID {
                userpilot?.clean()
                logout(socketState: .switchingUser)
            } else {
                flushPriorityEvents()
            }
        }
    }

    /**
     Processes and sends screen view events.
     
     - Ensures that the socket is open and the screen has not been previously viewed.
     - Resets the event count for a new screen view.
     
     - Parameter event: The screen event to process.
     */
    private func screen(_ event: Event) {
        tryCatch {
            if eventThrottle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "") {
                return
            }
            setupScreenEvent(event)
            flushPriorityEvents()
        }
    }

    /**
     Tracks general user events.
     
     - Ensures the event count and uniqueness constraints are met before publishing.
     
     - Parameter event: The event to track.
     */
    private func trackEvent(_ event: Event) {
        tryCatch {
            readWriteLock.write { [weak self] in
                guard let self else { return }
                if self.eventThrottle.shouldThrottle(eventTitle: event.eventTitle) { return }
                self.eventsName.insert(event.eventTitle)
                self.eventsToFlush.append(event)
                if self.eventsToFlush.count == 1 {
                    flushQueue()
                }
            }
        }
    }

    /**
     Sets up the screen event by updating the `screenViewEntity` based on the given event.

     If the screen title of the incoming event differs from the current `screenViewEntity`'s event:
     - The `startSession` flag is set to `false`.
     - A new `ScreenViewEntity` is created with an empty set of seen experiences.

     If the screen title matches the current `screenViewEntity`'s event:
     - A new `ScreenViewEntity` is created, retaining the existing set of seen experiences.

     - Parameter event: The new screen event to process.
     */
    private func setupScreenEvent(_ event: Event) {
        tryCatch {
            // Check if the screen title has changed
            let isScreenTitleChanged = screenViewEntity?.event.screenTitle != event.screenTitle

            // Update session state if the screen title has changed
            if screenViewEntity != nil && isScreenTitleChanged {
                startSession = false
            }

            // Update the `screenViewEntity` with the new event and handle seen experiences accordingly
            if isScreenTitleChanged {
                // New screen: start with an empty set of seen experiences
                screenViewEntity = ScreenViewEntity(event: event, seenExperiences: Set())
            } else {
                // Same screen: retain the existing seen experiences
                let seenExperiences = screenViewEntity?.seenExperiences ?? Set()
                screenViewEntity = ScreenViewEntity(event: event, seenExperiences: seenExperiences)
            }
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
        tryCatch {
            if !socketManager.isSocketOpened || socketManager.isJoiningSocket {
                checkFallbackState()
                return
            }

            /// Identify event
            if let cachedIdentifyEvent {
                var payload: [String: Any] = [:]
                guard let userID = cachedIdentifyEvent.userID else { return }
                // In-case identify event called again when joining socket channel
                if storage.userID.isNotEmpty && userID != storage.userID {
                    identify(cachedIdentifyEvent)
                    return
                }
                payload[AnalyticsPublisher.metaDataProperty] = cachedIdentifyEvent.properties ?? [:]
                if let company = cachedIdentifyEvent.company, !company.isEmpty {
                    payload[AnalyticsPublisher.identifyCompanyProperty] = company
                }
                socketManager.publish(cachedIdentifyEvent.eventName, payload: payload)
            }

            /// Screen event
            if let screenViewEntity {
                var payload: [String: Any] = [:]
                payload[AnalyticsPublisher.screenTitleProperty] = screenViewEntity.event.screenTitle
                payload[AnalyticsPublisher.metaDataProperty] = [
                    AnalyticsPublisher.isSessionStartedProperty: startSession,
                    AnalyticsPublisher.fakeReload: false,
                    AnalyticsPublisher.seenContents: Array(screenViewEntity.seenExperiences)
                ]
                socketManager.publish(screenViewEntity.event.eventName, payload: payload)
                broadcastEvent(screenViewEntity.event, screenViewEntity.event.screenTitle ?? "", properties: nil)
            }

            /// Track event
            if let cachedEvent {
                trackEvent(cachedEvent)
            }
        }
    }

    /**
     Flush the queue directly, for example when application moves to background
     */
    private func flushQueue(shouldCloseSocket: Bool = false, flushImmediately: Bool = false) {
        tryCatch {
            readWriteLock.write { [weak self] in
                guard let self else { return }
                if !self.socketManager.isSocketOpened || self.socketManager.isJoiningSocket {
                    self.checkFallbackState()
                    return
                }
                if self.eventsToFlush.isEmpty {
                    if shouldCloseSocket { self.closeSocket() }
                    return
                }

                if let eventToSend = self.eventsToFlush.first {
                    self.eventsToFlush.removeFirst()

                    var payload: [String: Any] = [:]
                    payload[AnalyticsPublisher.eventNameProperty] = eventToSend.eventTitle
                    payload[AnalyticsPublisher.metaDataProperty] = eventToSend.properties ?? [:]

                    self.broadcastEvent(eventToSend, eventToSend.eventTitle, properties: payload)
                    self.socketManager.publish(
                        eventToSend.eventName,
                        payload: payload,
                        shouldCloseSocket: shouldCloseSocket
                    )

                    if flushImmediately {
                        self.flushQueue(shouldCloseSocket: shouldCloseSocket, flushImmediately: true)
                    } else {
                        if !shouldCloseSocket {
                            self.flushQueue()
                        }
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

    // Fallback state to close socket if channel not opened
    private func checkFallbackState() {
        if socketManager.isSocketConnectedWithUnknownChannel { closeSocket() }
    }

    /// Socket closed callback.
    func onSocketClosed() {
        tryCatch {
            if socketManager.didErrorOccurred {
                clearAllCachedProperties()
                return
            }
            if let eventToPublish = cachedIdentifyEvent {
                userpilot?.clean()
                publish(eventToPublish)
            } else {
                clearAllCachedProperties()
            }
        }
    }

    /**
     Callback method triggered when a socket event has been sent, ensuring any remaining queued events are flushed.

     - Parameters:
       - eventName: The name of the event sent.
       - eventSent: Whether the event was successfully sent.
     */
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        tryCatch {
            if let cachedIdentifyEvent {
                if eventName == EventType.identifyEvent &&
                    cachedIdentifyEvent.userID == storage.userID {
                    var newUser = User.fromJson(storage.user)
                    storage.user = newUser.updateUser(event: cachedIdentifyEvent).toJson() ?? ""
                    logger.info("👤 USER %{public}@", storage.user)
                    clearCachedIdentifyEvent()
                    broadcastEvent(cachedIdentifyEvent, cachedIdentifyEvent.userID ?? "", properties: payload)
                }
            }
            flushQueue()
        }
    }

}

// MARK: - Reset cached properties

private extension AnalyticsPublisher {

    /// Clear all cached properties in case we get closed callback from socket.
    private func clearAllCachedProperties(_ shouldClearCachedIdentifyEvent: Bool = false) {
        clearCachedEvents()
        clearCachedEvent()
        if shouldClearCachedIdentifyEvent { clearCachedIdentifyEvent() }
    }

    /// Clears the cached events on new identify event or when socket opened.
    private func clearCachedEvents() {
        tryCatch {
            readWriteLock.write { [weak self] in
                guard let self else { return }
                self.eventsToFlush.removeAll()
            }
        }
    }

    /// Clears the cached identify event after it has been successfully sent.
    private func clearCachedIdentifyEvent() {
        cachedIdentifyEvent = nil
        storage.temporaryUser = nil
    }

    /// Clears the cached identify event after it has been successfully sent.
    private func clearCachedEvent() {
        cachedEvent = nil
    }

}

// MARK: - Experiences events

extension AnalyticsPublisher {

    /// check socket state
    var canRequestEvent: Bool {
        socketManager.isSocketOpened
    }

    /// For experience which are come from start session
    var isStartSession: Bool {
        startSession
    }

    /// publish experience event
    func publishExperienceEvent(
        _ sdkEvent: SDKEvent,
        isExpereinceEvent: Bool,
        socketSubscription: SocketSubscription
    ) {
        tryCatch {
            if isExpereinceEvent {
                guard canRequestEvent else { return }
            }
            socketManager.publish(
                sdkEvent.eventName,
                payload: sdkEvent.eventPayload,
                socketSubscription: socketSubscription
            )
        }
    }

    /// publish fake reload event
    func publishFakeReloadScreenEvent() {
        tryCatch {
            guard canRequestEvent else { return }
            if let screenViewEntity {
                if eventThrottle.shouldThrottleScreenEvent(screenTitle: screenViewEntity.event.screenTitle ?? "") {
                    return
                }
                var payload: [String: Any] = [:]
                payload[AnalyticsPublisher.screenTitleProperty] = screenViewEntity.event.screenTitle
                payload[AnalyticsPublisher.metaDataProperty] = [
                    AnalyticsPublisher.isSessionStartedProperty: startSession,
                    AnalyticsPublisher.fakeReload: true,
                    AnalyticsPublisher.seenContents: Array(screenViewEntity.seenExperiences)
                ]
                socketManager.publish(screenViewEntity.event.eventName, payload: payload)
            }
        }
    }

    /// update seen experiences
    func experiencePublished(_ experienceId: Int) {
        screenViewEntity?.updateSeenExperiences(experienceId)
    }

}

// MARK: - broadcast event

internal extension AnalyticsPublisher {

    func broadcastEvent(_ event: Event, _ value: String, properties: [String: Any]?) {
        performOn(.main) { [weak self] in
            self?.userpilot?.analyticsDelegate?.didTrack(
                analytic: event.userpilotAnalytic,
                value: value,
                properties: properties)
        }
    }

}

// MARK: - Properties name

internal extension AnalyticsPublisher {

    // Static constants
    static let metaDataProperty = "metadata"
    private static let identifyCompanyProperty = "company"

    static let screenTitleProperty = "title"
    static let isSessionStartedProperty = "is_session_start"
    static let fakeReload = "fake_reload"
    static let seenContents = "seen_contents"
    private static let eventNameProperty = "event_name"
}
