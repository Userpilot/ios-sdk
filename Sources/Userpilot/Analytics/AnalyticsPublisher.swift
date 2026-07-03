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
import UIKit

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
    func logout(
        socketState: SocketManager.SocketState,
        shouldClearCachedIdentifyEvent: Bool
    )

    /// check socket state
    var canRequestEvent: Bool { get }

    /// publish experience event
    func publishInternalSDKEvent(
        _ sdkEvent: SDKEvent,
        socketSubscription: SocketSubscription?
    )

    /// publish fake reload event
    func publishFakeReloadScreenEvent(_ experienceType: ExperienceType, _ experienceId: Int?)

    /// update seen experiences
    func experiencePublished(
        _ experienceType: ExperienceType,
        _ experienceId: Int
    )

    /// For experience which are come from start session
    var isStartSession: Bool { get }

    /// To return current screen entity
    var screenEntity: ScreenViewEntity? { get }
}

/**
 * AnalyticsPublisher is responsible for managing and publishing analytics events through WebSocket connections.
 *
 * This class handles:
 * - Event queuing and throttling
 * - Socket connection management
 * - User identification and session management
 * - Screen tracking with experience state management
 * - Background/foreground state handling
 *
 * The publisher ensures events are sent reliably by caching them when the socket is unavailable
 * and flushing them once the connection is re-established.
 */
internal class AnalyticsPublisher {

    // MARK: - Constants

    /** Property key for event metadata */
    static let metaDataProperty = "metadata"

    /** Property key for event screen */
    static let screen = "screen"

    /** Property key for company information in identify events */
    static let identifyCompanyProperty = "company"

    /** Property key for screen title in screen events */
    static let screenTitleProperty = "title"

    /** Property key indicating if this is the start of a new session */
    static let isSessionStartedProperty = "is_session_start"

    /** Property key for fake reload state */
    static let fakeReload = "fake_reload"

    /** Property key for tracking seen flows/experiences */
    static let seenContents = "seen_contents"

    /** Property key for tracking seen surveys */
    static let seenSurveys = "seen_surveys"

    /** Property key for custom event names */
    private static let eventNameProperty = "event_name"

    // MARK: - Properties

    /// A weak reference to ExperienceRendering would be expected here to avoid a retain cycle with AnalyticsPublisher
    private weak var container: DIContainer?

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?

    /// The configuration settings for the `Userpilot` SDK.
    private let config: Userpilot.Config

    /// SDK logger.
    private let logger: Logging

    /// The storage used to store user-related data.
    private let storage: DataStoring

    /// The experience publisher.
    private weak var experiencesPublisher: ExperiencesPublishing? {
        return container?.resolve(ExperiencesPublishing.self)
    }

    /// Session monitoring to track app state
    private weak var sessionMonitorer: SessionMonitoring? {
        return container?.resolve(SessionMonitoring.self)
    }

    /// Decorator used to modify event properties before sending.
    private let autoPropertyDecorator: AutoPropertyDecoratoring

    /// The screen name tracker.
    private let screenNameTracker: ScreenNameTracking

    /// Manages socket connections and event publishing over web socket.
    private let socketManager: SocketEvents

    // MARK: - Properties

    /// Queue to hold events waiting to be sent
    private lazy var eventsToFlush = [Event]()

    /// Read-write lock for thread-safe event queue operations
    private lazy var readWriteLock = ReadWriteLock()

    /// Event throttling mechanism to prevent spam
    private lazy var eventThrottle = EventThrottle(throttleDuration: 1.0)

    /**
     * Tracks the last screen viewed and its state including seen experiences.
     * Contains boolean flag for fake reload state.
     */
    private(set) var screenViewEntity: ScreenViewEntity?

    /// Cached identify event, to be sent when the socket is ready
    private var cachedIdentifyEvent: Event?

    /// Tracks the first event to open the socket
    private var cachedEvent: Event?

    /// Holds session start state - true indicates a new session should be started
    private var startSession = true

    // MARK: - Initialization

    /**
     * Initializes the AnalyticsPublisher with dependencies from the provided dependency injection container.
     * Restores any previously cached user from storage.
     *
     * - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.container = container
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.socketManager = container.resolve(SocketEvents.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)
        self.logger = container.resolve(Userpilot.Config.self).logger

        // Register socket event callback
        self.socketManager.registerCallback(self)

        // Restore any previously cached user from storage
        if let temporaryUserString = storage.temporaryUser {
            let temporaryUser = User.fromJson(temporaryUserString)
            cachedIdentifyEvent = Event(
                type: EventType.identify(temporaryUser.userId),
                properties: temporaryUser.properties,
                company: temporaryUser.company)
        }
    }

}

// MARK: - AnalyticsPublishing

extension AnalyticsPublisher: AnalyticsPublishing {

    // MARK: - Public Methods

    /**
     * Flushes all pending events when the app enters background.
     * This ensures no events are lost when the app is backgrounded.
     */
    func flush() {
        socketManager.updateSocketState(.shuttingDown, forceUpdateState: true)
        flushQueue(shouldCloseSocket: true)
    }

    /**
     * Clears all cached data and closes the socket connection.
     *
     * - Parameter socketState: The state to set for the socket after logout
     * - Parameter shouldClearCachedIdentifyEvent: If true, indicates this logout comes from app level,
     *        meaning the user is logged out and there is no new login. This will clear the
     *        push token from the backend. On user switch, the backend handles clearing the
     *        push token from the old user.
     */
    func logout(
        socketState: SocketManager.SocketState,
        shouldClearCachedIdentifyEvent: Bool = false
    ) {
        if shouldClearCachedIdentifyEvent && canRequestEvent {
            if let token = storage.pushToken {
                publishInternalSDKEvent(
                    UserLogoutEvent(
                        appToken: config.token,
                        userId: storage.userId,
                        token: token),
                    socketSubscription: nil
                )
            }
        }
        // Reset start session for next login user
        startSession = true
        // Reset content states
        experiencesPublisher?.logout()
        // Clear seen contents from screenViewEntity
        screenViewEntity?.resetState()
        // Update socket state: SHUTTING_DOWN for app logout, otherwise SWITCHING_USER state
        socketManager.updateSocketState(socketState, forceUpdateState: true)
        // Clear all content for app logout, otherwise keep them to re-establish connection
        // after closing old user channel
        clearAllCachedProperties(shouldClearCachedIdentifyEvent)
        // Close socket connection
        socketManager.close()
    }

    /**
     * Resumes socket connection when app opens or returns from background.
     * This is the entry point that establishes socket connection.
     */
    func resume() {
        updateSessionState()
        if let userId = cachedIdentifyEvent?.userId, !userId.isEmpty {
            storage.userId = userId
        }
        if storage.userId.isNotEmpty && !socketManager.isSocketOpened && !socketManager.isJoiningSocket {
            openSocket()
        }
    }

    /**
     * Reset session state
     */
    func reset() {
        startSession = true
        eventThrottle.clear()
    }

    /**
     * Compares the saved date with the current date and returns true if the difference is more than 30 minutes.
     * Updates startSession when comparing storage.sessionDate with current date if it's
     * more than 30 minutes.
     */
    func updateSessionState() {
        guard let sessionDate = storage.sessionDate else { return }
        storage.sessionDate = nil
        let difference = Date().timeIntervalSince(sessionDate)
        startSession = difference > GeneralConstants.SESSION_DURATION
    }

    // MARK: - Publish Helper Methods

    /**
     * Publishes an event to the server through the WebSocket connection.
     * If the socket is not opened or still in the process of joining, the event is cached for later.
     *
     * - Parameter event: The event to be published. The type of the event determines the action to be taken.
     */
    func publish(_ event: Event) {
        tryCatch {
            // Handle app state - cache events when app is not in active state
            guard sessionMonitorer?.isAppActive ?? false else {
                cacheEvent(event)
                return
            }

            guard !didHandleIdentifyEvent(event) else { return }

            // Check if socket is in shutdown state
            // For example: getting event while logging out, ignore the event
            guard !socketManager.isShutdownState else { return }

            // Handle socket joining state
            // If socket is joining, cache the event to process it after establishing socket connection
            guard !socketManager.isJoiningSocket else {
                cacheEvent(event)
                return
            }

            // Handle closed socket state
            // If socket is closed, cache event and verify there is a valid
            // user ID, then establish connection and return
            guard socketManager.isSocketOpened else {
                handleClosedSocket(event)
                return
            }

            // Socket is opened, process the event immediately
            processEvent(event)
        }
    }

    /**
     * Handles identify events by checking for duplicate users and caching the event.
     *
     * - Parameter event: The identify event to handle
     * - Returns: true if the event should be ignored (same user), false if processing should continue
     */
    private func didHandleIdentifyEvent(_ event: Event) -> Bool {
        guard event.isIdentifyEvent else { return false }

        // When same user, return true to stop and ignore event
        guard !(storage.user.isNotEmpty && User.fromJson(storage.user).isSameIdentifyEvent(event: event)) else {
            return true
        }

        // Update cached user
        storage.temporaryUser = event.toUser().toJson()
        cachedIdentifyEvent = event

        return false
    }

    /**
     * Handles events when socket is closed by caching the event and attempting to open connection.
     *
     * - Parameter event: The event to handle
     * - Returns: true if processing should stop, false if it should continue
     */
    private func handleClosedSocket(_ event: Event) {
        cacheEvent(event)

        // Update userId from cached identify event or current event
        updateUserIdFromEvent(event)

        // Only proceed if we have a valid userId
        if storage.userId.isEmpty { return }

        openSocket()
    }

    /**
     * Updates the stored user ID from the event, prioritizing current event over cached identify event.
     *
     * - Parameter event: The event containing potential user ID
     */
    private func updateUserIdFromEvent(_ event: Event) {
        // Priority: current event userId > cached identify event userId
        if let userId = event.userId, !userId.isEmpty {
            storage.userId = userId
        } else if let cachedUserId = cachedIdentifyEvent?.userId, !cachedUserId.isEmpty {
            storage.userId = cachedUserId
        }
    }

    /**
     * Processes an event based on its type.
     *
     * - Parameter event: The event to process
     */
    private func processEvent(_ event: Event) {
        switch event.type {
        case .identify:
            identify(event)
        case .screen:
            screen(event)
        case .event, .autoCaptureEvent:
            trackEvent(event)
        }
    }

    /**
     * Caches an event when socket is not opened or is joining.
     * Different event types are cached in different properties.
     *
     * - Parameter event: The event to cache
     */
    private func cacheEvent(_ event: Event) {
        switch event.type {
        case .identify:
            cachedIdentifyEvent = event
        case .screen:
            setupScreenEvent(event)
        case .event, .autoCaptureEvent:
            cachedEvent = event
        }
    }

    // MARK: - Private Methods

    /**
     * Identifies the user and handles the identify event.
     * If a new user ID is detected, it closes the socket and cleans up for user switching.
     *
     * - Parameter event: The identify event containing user information
     */
    private func identify(_ event: Event) {
        tryCatch {
            guard let userId = event.userId else { return }

            // If new user ID detected, close socket and clean up
            if storage.userId.isNotEmpty && userId != storage.userId {
                userpilot?.clean()
                logout(socketState: .switchingUser)
            } else {
                flushPriorityEvents(fakeReloadScreenEvent: true)
            }
        }
    }

    /**
     * Processes and sends screen view events.
     * Handles screen throttling and determines when to trigger screen events.
     *
     * - Parameter event: The screen event to process
     */
    private func screen(_ event: Event) {
        tryCatch {
            // Returns true if this is a new screen, which triggers screen event and throttling
            if setupScreenEvent(event) {
                _ = eventThrottle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "")
                flushPriorityEvents(isRequestIdentify: false)
                return
            }
            // Not a new screen, check if valid to trigger screen event
            if experiencesPublisher?.canRequestScreenEvent() == false ||
                eventThrottle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "") {
                return
            }
            flushPriorityEvents(isRequestIdentify: false)
        }
    }

    /**
     * Stable key for event throttling.
     * Non-AutoCapture events use `eventTitle`, or `eventName` when
     * the title is empty; autocapture joins every available discriminator
     * into a fixed-arity key. Missing discriminators degrade to empty
     * segments instead of an early return to a coarser key, so events
     * never collapse back onto the shared autocapture title.
     */
    private func trackEventThrottleKey(_ event: Event) -> String {
        guard case .autoCaptureEvent = event.type else {
            let eventTitle = event.eventTitle
            return eventTitle.isEmpty ? event.eventName : eventTitle
        }

        let properties = event.properties ?? [:]
        func prop(_ key: String) -> String {
            trackEventThrottleString(from: properties[key])
        }

        let rawInteraction = prop(AutoCaptureConstants.rawInteractionType)

        return [
            trackEventThrottleScreenName(from: event.screen),
            event.eventName,
            rawInteraction.isEmpty ? (event.interactionEventName ?? "") : rawInteraction,
            prop(AutoCaptureConstants.tabName),
            prop(AutoCaptureConstants.hierarchy),
            prop(AutoCaptureConstants.accessibilityIdentifier),
            prop(AutoCaptureConstants.dialogTitle),
            prop(AutoCaptureConstants.targetText),
            prop(AutoCaptureConstants.section),
            prop(AutoCaptureConstants.selectedIndex),
            prop(AutoCaptureConstants.selectedValue),
            prop(AutoCaptureConstants.placeholder),
            prop(AutoCaptureConstants.accessibilityLabel)
        ].joined(separator: "|")
    }

    /// Resolves a display class for throttling from `Event.screen` (set on autocapture events via `makeEvent`).
    private func trackEventThrottleScreenName(from screen: Payload) -> String {
        guard let screen, !screen.isEmpty else { return "" }
        if let name = screen[AutoCaptureConstants.screenClass] as? String, !name.isEmpty { return name }
        if let name = screen[AutoCaptureConstants.screenTitle] as? String, !name.isEmpty { return name }
        if let name = screen[AutoCaptureConstants.screenName] as? String, !name.isEmpty { return name }
        return ""
    }

    private func trackEventThrottleString(from value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    /**
     * Tracks general user events by adding them to the flush queue.
     * Events are throttled to prevent spam.
     *
     * - Parameter event: The custom event to track
     */
    private func trackEvent(_ event: Event) {
        tryCatch {
            readWriteLock.write { [weak self] in
                guard let self else { return }
                let throttleKey = trackEventThrottleKey(event)
                if self.eventThrottle.shouldThrottle(eventTitle: throttleKey) { return }
                self.eventsToFlush.append(event)
                if self.eventsToFlush.count == 1 {
                    flushQueue()
                }
            }
        }
    }

    // MARK: - Screen Management

    /**
     * Sets up the screen event by updating the screenViewEntity based on the given event.
     *
     * If the screen title of the incoming event differs from the current screenViewEntity's event:
     * - The startSession flag is set to false
     * - A new ScreenViewEntity is created with an empty set of seen experiences
     *
     * If the screen title matches the current screenViewEntity's event:
     * - A new ScreenViewEntity is created, retaining the existing set of seen experiences
     *
     * - Parameter event: The new screen event to process
     * - Returns: true if this is a new screen, false if it's the same screen
     */
    @discardableResult
    private func setupScreenEvent(_ event: Event) -> Bool {
        var isNewScreen = false
        tryCatch {
            // Check if the screen title has changed
            let isScreenTitleChanged = screenViewEntity?.event.screenTitle != event.screenTitle

            // Update session state if the screen title has changed
            if screenViewEntity != nil && socketManager.isSocketOpened && isScreenTitleChanged {
                startSession = false
            }

            // Update the screenViewEntity with the new event and handle seen experiences accordingly
            if isScreenTitleChanged {
                isNewScreen = true

                // New screen: start with an empty set of seen experiences
                screenViewEntity = ScreenViewEntity(
                    event: event,
                    seenExperiences: Set(),
                    seenSurveys: Set()
                )
            } else {
                // Same screen: retain the existing seen experiences
                screenViewEntity = ScreenViewEntity(
                    event: event,
                    seenExperiences: screenViewEntity?.seenExperiences ?? Set(),
                    seenSurveys: screenViewEntity?.seenSurveys ?? Set()
                )
            }
        }
        return isNewScreen
    }

}

// MARK: - Socket Subscription Management

extension AnalyticsPublisher {

    /*
     * Flushes high-priority events, such as identify or screen events, through the socket.
     * These are events that open the socket or are critical for user tracking.
     *
     * - Parameter isRequestIdentify: When socket opens or identifies new user, request identify.
     *        If from screen event, don't request identify to avoid duplicates.
     * - Parameter canRequestScreenEvent: Request screen from screen event, from identify new user
     *        and we have cached screen. Check ExperiencePublisher state for validation.
     * - Parameter fakeReloadScreenEvent: When from identify (update user properties), request
     *        identify with fake reload true, otherwise false.
     */
    // swiftlint:disable:next function_body_length
    private func flushPriorityEvents(
        isRequestIdentify: Bool = true,
        canRequestScreenEvent: Bool = true,
        fakeReloadScreenEvent: Bool = false
    ) {
        tryCatch {
            if !socketManager.isSocketOpened || socketManager.isJoiningSocket {
                checkFallbackState()
                return
            }

            // Handle identify event
            if isRequestIdentify {
                if let cachedIdentifyEvent {
                    var payload: [String: Any] = [:]
                    guard let userId = cachedIdentifyEvent.userId else { return }
                    // If identify event is called again when joining socket channel
                    if storage.userId.isNotEmpty && userId != storage.userId {
                        identify(cachedIdentifyEvent)
                        return
                    }
                    payload[AnalyticsPublisher.metaDataProperty] = cachedIdentifyEvent.properties ?? [:]
                    if let company = cachedIdentifyEvent.company, !company.isEmpty {
                        payload[AnalyticsPublisher.identifyCompanyProperty] = company
                    }
                    socketManager.publish(cachedIdentifyEvent.eventName, payload: payload)
                }
            }

            // Handle screen event
            if let screenViewEntity, canRequestScreenEvent {
                let screenEvent = screenViewEntity.event
                if let screenTitle = screenEvent.screenTitle {
                    if shouldSyncManualScreenForInteractionPayload() {
                        screenNameTracker.updateScreen(
                            with: ScreenTrackingPayload(
                                screenTitle: screenTitle,
                                appFramework: config.appFramework
                            )
                        )
                    }
                    experiencesPublisher?.updateSceen(screenTitle)
                }
                var payload: [String: Any] = [:]
                payload[AnalyticsPublisher.screenTitleProperty] = screenEvent.screenTitle ?? ""

                let existingMetadata = screenViewEntity.event.properties ?? [:]
                let newMetadata: [String: Any] = [
                    AnalyticsPublisher.isSessionStartedProperty: startSession,
                    AnalyticsPublisher.fakeReload: fakeReloadScreenEvent,
                    AnalyticsPublisher.seenContents: Array(screenViewEntity.seenExperiences),
                    AnalyticsPublisher.seenSurveys: Array(screenViewEntity.seenSurveys)
                ]
                payload[AnalyticsPublisher.metaDataProperty] = existingMetadata.merging(newMetadata) { _, new in new }

                socketManager.publish(screenEvent.eventName, payload: payload)
                broadcastEvent(screenEvent, screenEvent.screenTitle ?? "", properties: nil)
            }

            // Handle cached track event
            if let cachedEvent {
                trackEvent(cachedEvent)
                clearCachedEvent()
            }
        }
    }

    private func shouldSyncManualScreenForInteractionPayload() -> Bool {
        if config.isWrapperSDK {
            return !config.isWrapperScreenAutoCaptureEnabled &&
                config.isWrapperInteractionAutoCaptureEnabled
        }
        return !config.enableScreenAutoCapture && config.enableInteractionAutoCapture
    }

    /*
     * Flushes the event queue by sending events one by one through the socket.
     *
     * - Parameter shouldCloseSocket: When move app to background
     */
    private func flushQueue(shouldCloseSocket: Bool = false) {
        tryCatch {
            readWriteLock.write { [weak self] in
                guard let self else { return }
                if !self.socketManager.isSocketOpened || self.socketManager.isJoiningSocket {
                    if shouldCloseSocket {
                        self.socketManager.close()
                    } else {
                        self.checkFallbackState()
                    }
                    return
                }
                if self.eventsToFlush.isEmpty {
                    if shouldCloseSocket { self.closeSocket() }
                    return
                }

                if let eventToSend = self.eventsToFlush.first {
                    self.eventsToFlush.removeFirst()

                    var payload: [String: Any] = [:]
                    payload[AnalyticsPublisher.eventNameProperty] =
                        eventToSend.type == .autoCaptureEvent
                        ? eventToSend.interactionEventName
                        : eventToSend.eventTitle
                    payload[AnalyticsPublisher.metaDataProperty] = eventToSend.properties ?? [:]
                    if let screen = eventToSend.screen {
                        payload[AnalyticsPublisher.screen] = screen
                    }
                    if eventToSend.type == .autoCaptureEvent && eventToSend.screen?.isEmpty != false {
                        self.logger.error("❗ Event Error, Auto capture event must have screen")
                        return
                    }

                    self.broadcastEvent(eventToSend, eventToSend.eventTitle, properties: payload)
                    self.socketManager.publish(eventToSend.eventName, payload: payload)
                    self.flushQueue(shouldCloseSocket: shouldCloseSocket)
                }
            }
        }
    }

    /**
     * Fallback state handler to close socket if channel is not opened properly.
     */
    private func checkFallbackState() {
        if socketManager.isSocketConnectedWithUnknownChannel { closeSocket() }
    }

}

// MARK: - Socket Management

extension AnalyticsPublisher: SocketSubscription {

    /// Opens the socket connection
    private func openSocket() {
        socketManager.connect()
    }

    /**
     * Closes the socket connection.
     * Used when a new user is identified, then reopens the socket for the new user via callback.
     */
    private func closeSocket() {
        socketManager.close()
    }

    /**
     * Socket opened callback.
     * Clears cached events and flushes priority events.
     */
    func onSocketOpened() {
        clearCachedEvents()
        flushPriorityEvents(canRequestScreenEvent: experiencesPublisher?.canRequestScreenEvent() == true)
    }

    /**
     * Socket closed callback.
     * Handles reconnection logic or clears cached properties based on closure reason.
     */
    func onSocketClosed() {
        tryCatch {
            if socketManager.isShutdownState || socketManager.didErrorOccurred {
                clearAllCachedProperties()
                return
            }
            if let eventToPublish = cachedIdentifyEvent {
                publish(eventToPublish)
            } else {
                clearAllCachedProperties()
            }
        }
    }

    /**
     * Callback method triggered when a socket event has been sent.
     * Ensures any remaining queued events are flushed and handles identify event completion.
     *
     * - Parameter eventName: The name of the event sent
     * - Parameter payload: The payload that was sent
     * - Parameter message: The socket message response
     * - Parameter eventSent: Whether the event was successfully sent
     */
    func onSocketEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ eventSent: Bool
    ) {
        tryCatch {
            if let cachedIdentifyEvent {
                if eventName == EventType.identifyEvent &&
                    cachedIdentifyEvent.userId == storage.userId {
                    var newUser = User.fromJson(storage.user)
                    storage.user = newUser.updateUser(event: cachedIdentifyEvent).toJson() ?? ""
                    logger.info("👤 USER %{public}@", storage.user)
                    clearCachedIdentifyEvent()
                    broadcastEvent(cachedIdentifyEvent, cachedIdentifyEvent.userId ?? "", properties: payload)
                }
            }
            flushQueue()
        }
    }

}

// MARK: - Cache Management

private extension AnalyticsPublisher {

    /**
     * Clears all cached properties when receiving closed callback from socket.
     *
     * - Parameter shouldClearCachedIdentifyEvent: Whether to clear the cached identify event
     */
    private func clearAllCachedProperties(_ shouldClearCachedIdentifyEvent: Bool = false) {
        clearCachedEvents()
        clearCachedEvent()
        if shouldClearCachedIdentifyEvent { clearCachedIdentifyEvent() }
    }

    /** Clears the cached events on new identify event or when socket opens */
    private func clearCachedEvents() {
        tryCatch {
            readWriteLock.write { [weak self] in
                guard let self else { return }
                self.eventsToFlush.removeAll()
            }
        }
    }

    /** Clears the cached identify event after it has been successfully sent */
    private func clearCachedIdentifyEvent() {
        cachedIdentifyEvent = nil
        storage.temporaryUser = nil
    }

    /** Clears the cached event after it has been successfully sent */
    private func clearCachedEvent() {
        cachedEvent = nil
    }
}

#if DEBUG
internal extension AnalyticsPublisher {
    func mockGetCachedEvent() -> Event? {
        return cachedEvent
    }

    func mockGetEventsToFlush() -> [Event] {
        return eventsToFlush
    }
}
#endif

// MARK: - Experience Publisher Integration

extension AnalyticsPublisher {

    /**
     * Checks if socket is open and ready to send events.
     *
     * - Returns: true if socket is open and can accept events
     */
    var canRequestEvent: Bool {
        socketManager.isSocketOpened
    }

    /// For experience which are come from start session
    var isStartSession: Bool {
        startSession
    }

    /// To return current screen entity
    var screenEntity: ScreenViewEntity? {
        screenViewEntity
    }

    /**
     * Publishes internal SDK events through the socket.
     *
     * - Parameter sdkEvent: The SDK event to publish
     * - Parameter socketSubscription: Optional listener for socket events
     */
    func publishInternalSDKEvent(
        _ sdkEvent: SDKEvent,
        socketSubscription: SocketSubscription?
    ) {
        tryCatch {
            guard canRequestEvent else { return }
            socketManager.publish(
                sdkEvent.eventName,
                payload: sdkEvent.eventPayload,
                socketSubscription: socketSubscription
            )
        }
    }

    /**
     * Publishes a fake reload screen event when an experience is shown.
     * This ensures proper state tracking for experiences.
     *
     * - Parameter experienceType: The type of experience (FLOW or SURVEY)
     * - Parameter experienceId: The ID of the experience being shown
     */
    func publishFakeReloadScreenEvent(_ experienceType: ExperienceType, _ experienceId: Int?) {
        tryCatch {
            guard
                experienceId != nil,
                canRequestEvent
            else { return }
            if let screenViewEntity {
                // update the seen content to make sure it contains the dismissed content that
                // trigger this fake reload
                experiencePublished(experienceType, experienceId!)
                if eventThrottle.shouldThrottleScreenEvent(screenTitle: screenViewEntity.event.screenTitle ?? "") {
                    return
                }
                var payload: [String: Any] = [:]
                payload[AnalyticsPublisher.screenTitleProperty] = screenViewEntity.event.screenTitle

                let existingMetadata = screenViewEntity.event.properties ?? [:]
                let newMetadata: [String: Any] = [
                    AnalyticsPublisher.isSessionStartedProperty: startSession,
                    AnalyticsPublisher.fakeReload: true,
                    AnalyticsPublisher.seenContents: Array(screenViewEntity.seenExperiences),
                    AnalyticsPublisher.seenSurveys: Array(screenViewEntity.seenSurveys)
                ]
                payload[AnalyticsPublisher.metaDataProperty] = existingMetadata.merging(newMetadata) { _, new in new }

                socketManager.publish(screenViewEntity.event.eventName, payload: payload)
                suppressScreenAutocaptureAfterFakeReload()
            }
        }
    }

    /// Suppresses automatic screen capture after sending a fake reload screen event.
    ///
    /// Fake reload is an SDK-generated screen event used to send `seen_contents` / `seen_surveys`
    /// without treating the close of SDK UI as real client navigation. After the fake reload is
    /// published, UIKit/SwiftUI may re-fire `viewWillAppear` for the underlying app screen hierarchy.
    /// This hook asks the autocapture coordinator to ignore that short lifecycle burst.
    private func suppressScreenAutocaptureAfterFakeReload() {
        guard config.enableScreenAutoCapture,
              config.appFramework == .SwiftUI
        else { return }
        // Dismissing this instance's SDK content can re-fire `viewWillAppear` on
        // every other registered instance's underlying UI as well. Route through
        // the resolver so all instances briefly suppress autocapture together.
        InstanceResolver.shared.suppressScreenAutoCaptureAfterSDKContent()
    }

    /**
     * Updates the seen experiences when an experience is published/shown.
     *
     * - Parameter experienceType: The type of experience that was shown
     * - Parameter experienceId: The ID of the experience that was shown
     */
    func experiencePublished(
        _ experienceType: ExperienceType,
        _ experienceId: Int
    ) {
        if experienceType == .flow {
            screenViewEntity?.updateSeenFlowExperiences(experienceId)
        } else {
            screenViewEntity?.updateSeenSurveyExperiences(experienceId)
        }
    }

}

// MARK: - Event Broadcasting

internal extension AnalyticsPublisher {

    /**
     * Broadcasts events to analytics listeners for external consumption.
     *
     * - Parameter event: The event to broadcast
     * - Parameter value: The event value/identifier
     * - Parameter properties: The event payload data
     */
    func broadcastEvent(
        _ event: Event,
        _ value: String,
        properties: [String: Any]?
    ) {
        performOn(.main) { [weak self] in
            self?.userpilot?.analyticsDelegate?.didTrack(
                analytic: event.userpilotAnalytic,
                value: value,
                properties: properties)
        }
    }

}
// swiftlint:enable file_length
