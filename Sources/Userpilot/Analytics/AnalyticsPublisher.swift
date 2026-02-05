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

/// The `AnalyticsPublishing` protocol defines the methods necessary
/// to publish analytic events and manage the event lifecycle.
internal protocol AnalyticsPublishing: AnyObject {
    /// Sends an event to the backend.
    func publish(_ event: Event, isInternalEvent: Bool)

    /// Flush any cached events or session data.
    func flush()

    /// Open socket connection.
    func resume()

    /// Logout user from socket
    func logout(clearCachedIdentifyEvent: Bool)

    /// check socket state
    var canRequestEvent: Bool { get }

    /// publish experience event
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// publish fake reload event
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?,
        isFakeReload: Bool)

    /// update seen experiences
    func experiencePublished(_ experienceType: ExperienceType?, _ experienceId: Int?)

    /// For experience which are come from start session
    var isStartSession: Bool { get }

    /// To return current screen entity
    var screenEntity: ScreenViewEntity? { get }
}

/// AnalyticsPublisher is responsible for managing and publishing analytics events through WebSocket connections.
///
/// This class handles:
/// - Event queuing and throttling
/// - Socket connection management
/// - User identification and session management
/// - Screen tracking with experience state management
/// - Background/foreground state handling
///
/// The publisher ensures events are sent reliably by caching them when the socket is unavailable
/// and flushing them once the connection is re-established.
internal class AnalyticsPublisher {

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

    /// Session monitoring to track app state.
    private weak var sessionMonitorer: SessionMonitoring? {
        return container?.resolve(SessionMonitoring.self)
    }

    /// Manages socket connections and event publishing over web socket.
    private let socketManager: SocketManaging

    /// Offline events handler for managing local storage and batch sending.
    private let offlineEventsHandler: OfflineEventsHandling

    /// Network monitor to check initial network readiness.
    private let networkMonitor: NetworkMonitoring

    /// The user session state manager
    private let userSessionStateManager: UserSessionStateManaging

    // MARK: - Properties
    /// Queue to hold SDK events to be sent.
    private lazy var cachedSDKEvents = [SDKEvent]()

    /// Event throttling mechanism to prevent spam.
    private lazy var eventThrottle = EventThrottle(throttleDuration: 1.0)

    /**
     * Tracks the last screen viewed and its state including seen experiences.
     * Contains boolean flag for fake reload state.
     */
    private(set) var screenViewEntity: ScreenViewEntity?

    /// Holds session start state - true indicates a new session should be started.
    private lazy var startSession = true

    /// Event queue to manage events
    private lazy var eventsQueue: EventQueue = EventQueue()

    /// Initial queue to hold events until network state is ready.
    private lazy var initialQueue: EventQueue = EventQueue()

    /// Tracks if offline data is being processed, to lock sending live events.
    private lazy var isProcessingEvent: AtomicReference<Bool> = AtomicReference(false)

    /// Date when start process latest event - as a fall back in case isProcessingEvent stuck.
    private var processEventDate: Date?

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
        self.socketManager = container.resolve(SocketManaging.self)
        self.offlineEventsHandler = container.resolve(OfflineEventsHandling.self)
        self.networkMonitor = container.resolve(NetworkMonitoring.self)
        self.userSessionStateManager = container.resolve(UserSessionStateManaging.self)
        self.logger = container.resolve(Userpilot.Config.self).logger

        // Register socket event callback
        self.socketManager.registerCallback(self)

        // Register network monitor delegate
        self.networkMonitor.delegate = self

        // Restore any previously cached user from storage
        if let temporaryUserString = storage.temporaryUser {
            let temporaryUser = User.fromJson(temporaryUserString)
            eventsQueue.enqueue(
                Event(
                    type: EventType.identify(temporaryUser.userId),
                    properties: temporaryUser.properties,
                    company: temporaryUser.company
                )
            )
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
        tryCatch {
            let events = eventsQueue.getAndClear()
            // In case of a new user, clear all queue and cache the identify new user event only
            let newUserEvents = events.filter { $0.isIdentifyEvent && $0.userId != storage.userId }
            if let firstNewUserEvent = newUserEvents.first {
                storage.temporaryUser = firstNewUserEvent.toUser().toJson()
                eventsQueue.enqueue(firstNewUserEvent)
            } else {
                events.forEach { event in
                    if event.isIdentifyEvent { identify(event) }
                    if event.isScreenEvent { screen(event) }
                    if event.isTrackEvent { trackEvent(event) }
                }
            }
            closeSocket()
            userSessionStateManager.markUserBackFromBackground()
        }
    }

    /**
     * Resumes socket connection when app opens or returns from background.
     * This is the entry point that establishes socket connection.
     */
    func resume() {
        updateSessionState()
        if let userId = getUserIdFromQueue() { storage.userId = userId }
        if !storage.userId.isEmpty && socketManager.isAllowToOpenSocket { openSocket() }
    }

    /**
     * Clears all cached data and closes the socket connection.
     *
     * - Parameter clearCachedIdentifyEvent: If true, indicates this logout comes from app level,
     *        meaning the user is logged out and there is no new login. This will clear the
     *        FCM token from backend. On user switch, the backend handles clearing the
     *        FCM token from the old user.
     */
    func logout(clearCachedIdentifyEvent: Bool = true) {
        if clearCachedIdentifyEvent && canRequestEvent {
            if let token = storage.pushToken {
                publishInternalSDKEvent(
                    UserLogoutEvent(
                        appToken: config.token,
                        userId: storage.userId,
                        token: token)
                )
            }
        }
        // Reset start session for next login user
        startSession = true
        // Reset content states
        experiencesPublisher?.resetState()
        // Clear seen contents from screenViewEntity
        screenViewEntity?.resetState()
        // Clear all content for app logout, otherwise keep them to re-establish connection
        // after closing old user channel
        clearEventsQueue(clearCachedIdentifyEvent)
        // Clear offline events
        offlineEventsHandler.clearLocalEvents()
        // Close socket connection
        closeSocket()
    }

    // MARK: - Publish Helper Methods

    /**
     * Publishes an event to the server through the WebSocket connection.
     * If the socket is not opened or still in the process of joining, the event is cached for later.
     *
     * - Parameter event: The event to be published. The type of the event determines the action to be taken.
     */
    func publish(_ event: Event, isInternalEvent: Bool = false) {
        tryCatch {
            // Keep last screen up to date with experience publish since now we have a queue events
            if let screenTitle = event.screenTitle {
                experiencesPublisher?.updateScreen(screenTitle)
            }

            // Handle app state - cache events when app is not in active state
            guard sessionMonitorer?.isAppActive ?? false else { return }

            // Cache identify event or return when its same user
            guard !didHandleIdentifyEvent(event) else { return }

            // Cache event while network monitor is still resolving initial state
            if !networkMonitor.isReady {
                initialQueue.enqueue(event, isInternalEvent: isInternalEvent)
                return
            }

            // If network monitor is ready and reports no network, save event to local storage
            if offlineEventsHandler.shouldSaveOffline && storage.userId.isNotEmpty {
                offlineEventsHandler.saveEventToLocalStorage(event: event)
                return
            }

            // Check if socket is in shutdown state
            // For example: getting event while logging out, ignore the event
            guard !socketManager.isShutdownState else { return }

            // since we are in valid state to process the event then add it to events queue
            cacheEvent(event, isInternalEvent: isInternalEvent)

            // Handle socket joining state
            // If socket is joining, cache the event to process it after establishing socket connection
            guard !socketManager.isJoiningSocket else { return }

            // Socket is opened, process the event immediately
            if canRequestEvent {
                processEvent()
            } else {
                // Handle closed socket state
                // If socket is closed, cache event and verify there is a valid user ID
                // then establish connection and return
                handleClosedSocket(event)
            }
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
        guard
            !(storage.user.isNotEmpty
                && User.fromJson(storage.user).isSameIdentifyEvent(event: event))
        else {
            return true
        }

        // Update temporary cached user in storage
        storage.temporaryUser = event.toUser().toJson()

        return false
    }

    /**
     * Handles events when socket is closed by caching the event and attempting to open connection.
     *
     * - Parameter event: The event to handle
     * - Returns: true if processing should stop, false if it should continue
     */
    private func handleClosedSocket(_ event: Event) {
        // Update userId from cached identify event or current event
        updateUserIdFromEvent(event)

        // Only proceed if we have a valid userId
        // This could be valid case when user logged out and sent tracked or screen event
        // then in this case return and don't processed the event, ignore it.
        guard !storage.userId.isEmpty else { return }

        openSocket()
    }

    /**
     * Updates the stored user ID from the event, prioritizing current event over cached identify event.
     *
     * - Parameter event: The event containing potential user ID
     */
    private func updateUserIdFromEvent(_ event: Event) {
        // Priority: current event userId > cached identify event userId
        // When socket is closed then handle user session state
        if event.isIdentifyEvent {
            if storage.userId == event.userId {
                userSessionStateManager.markAwaitingInitialScreen()
            } else {
                userSessionStateManager.markUserSwitch()
            }
        }

        if let userId = event.userId {
            storage.userId = userId
        } else if let cachedUserId = getUserIdFromQueue() {
            storage.userId = cachedUserId
        }
    }

    /** Processes an event based on its type. */
    private func processEvent() {
        tryCatch {
            // Safety check: skip if already processing and last run was less than 10s ago
            if isProcessingEvent.value, let lastProcessDate = processEventDate,
               Date().isLessThanTenSecond(from: lastProcessDate) {
                return
            }

            isProcessingEvent.value = true
            processEventDate = Date()

            // Priority 1: Check and process offline events FIRST
            if offlineEventsHandler.hasCachedEvents {
                offlineEventsHandler.restoreEventsFromLocalStorage { [weak self] in
                    // After offline events are restored and sent, reset processing status
                    // and continue processing queued events
                    self?.resetProcessingEventStatus()
                    self?.processEvent()
                }
                return
            }

            // Priority 2: Sync Internal SDK events directly
            processSDKEvent()

            // Priority 3: Process queue events only after offline events are done
            if let event = eventsQueue.getFirst() {
                // Double check user, this could occur when processing event become same to user
                if didHandleIdentifyEvent(event) {
                    eventsQueue.deleteFirst()
                    resetProcessingEventStatus()
                    processEvent()
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
            } else {
                if eventsQueue.isEmpty() &&
                    userSessionStateManager.getCurrentState() == .backgroundToInitialScreen {
                    publishFakeReloadScreenEvent(isFakeReload: false)
                    userSessionStateManager.markNormal()
                } else {
                    resetProcessingEventStatus()
                }
            }
        }
    }

    /**
     * Caches an event when socket is not opened or is joining.
     * Different event types are cached in different properties.
     *
     * - Parameter event: The event to cache
     */
    private func cacheEvent(_ event: Event, isInternalEvent: Bool = false) {
        if storage.userId.isEmpty {
            eventsQueue.clear()
        }
        // Throttle screen and track event before add them to eventsQueue
        if event.isScreenEvent, eventThrottle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "") {
            return
        }
        if event.isTrackEvent, eventThrottle.shouldThrottle(eventTitle: event.eventTitle) {
            return
        }
        eventsQueue.enqueue(event, isInternalEvent: isInternalEvent)
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

            // If new user ID detected, close socket and clean up, Socket is connected
            if storage.userId.isNotEmpty && userId != storage.userId {
                // when user switch this mark it as switch so the fake reload will be false
                userSessionStateManager.markUserSwitch()
                userpilot?.clean()
                logout(clearCachedIdentifyEvent: false)
            } else {
                // When socket is connected with same user id
                userSessionStateManager.markAwaitingInitialScreen()
                var payload: [String: Any] = [
                    Constants.Analytics.metaDataProperty: event.properties ?? [:]
                ]
                if let company = event.company, !company.isEmpty {
                    payload[Constants.Analytics.identifyCompanyProperty] = company
                }
                socketManager.publish(
                    event.eventName, payload: payload, isClosingSocket: isClosingSocket())
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
            // Returns true if this is a new screen, which triggers screen event
            if setupScreenEvent(event) {
                publishScreenEvent(isFakeReload: false)
                return
            }
            // Not a new screen, check if valid to trigger screen event
            if experiencesPublisher?.canRequestScreenEvent() == true {
                publishScreenEvent(isFakeReload: false)
            }
        }
    }

    /**
     * Tracks general user events by adding them to the flush queue.
     * Events are throttled to prevent spam.
     *
     * - Parameter event: The custom event to track
     */
    private func trackEvent(_ event: Event) {
        tryCatch {
            let payload: [String: Any] = [
                Constants.Analytics.eventNameProperty: event.eventTitle,
                Constants.Analytics.metaDataProperty: event.properties ?? [:]
            ]
            socketManager.publish(event.eventName, payload: payload, isClosingSocket: isClosingSocket())
            broadcastEvent(event, event.eventTitle, properties: payload)
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
            if screenViewEntity != nil && canRequestEvent && isScreenTitleChanged {
                startSession = false
            }

            // Update the screenViewEntity with the new event and handle seen experiences accordingly
            if isScreenTitleChanged {
                isNewScreen = true

                // New screen: start with an empty set of seen experiences
                screenViewEntity = ScreenViewEntity(
                    event: event, seenExperiences: Set(), seenSurveys: Set())
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

    /// Checks if socket is open and ready to send events.
    var canRequestEvent: Bool {
        socketManager.isSocketOpened
    }

    /**
     * Socket opened callback.
     * Clears cached events and flushes priority events.
     */
    func onSocketOpened() {
        tryCatch {
            processEvent()
        }
    }

    /**
     * Socket closed callback.
     * Handles reconnection logic or clears cached properties based on closure reason.
     */
    func onSocketClosed() {
        tryCatch {
            resetProcessingEventStatus()
            // Socket closed from error state, don't reopen, clear events
            if socketManager.didCloseFromError { return }
            // Have events in queue, then close come from switch user, reopen socket
            // and keep the identify event first event to process
            if let event = eventsQueue.dequeue() {
                // Mark user switch state for proper handling of new user's initial screen
                userSessionStateManager.markUserSwitch()
                publish(event, isInternalEvent: true)
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
        _ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool
    ) {
        tryCatch {
            // Important since we only send next event when getting acknowledgement from analytics Event
            guard eventName.isAnalyticsEvent() else { return }
            // Get first event, and remove it from queue, keep it here as we need to remove first one
            let event = eventsQueue.dequeue()

            // Update cached user object
            if let event, eventName == Constants.Event.identifyEvent && event.userId == storage.userId {
                var newUser = User.fromJson(storage.user)
                storage.user = newUser.updateUser(event: event).toJson() ?? ""
                logger.info("👤 USER %{public}@", storage.user)
                clearCachedIdentifyEvent()
                broadcastEvent(event, event.userId ?? "", properties: payload)
            }

            if eventName == Constants.Event.screenEvent {
                userSessionStateManager.markNormal()
            }

            // Handle request screen event after user identify event
            if userSessionStateManager.isPostIdentificationContext(eventName)
                && userSessionStateManager.shouldRequestInitialScreenEvent(
                    eventsQueue.isEmpty(),
                    experiencesPublisher?.getCurrentScreen.isNotEmpty == true) {
                publishScreenEvent(isFakeReload: userSessionStateManager.getPostIdentificationFakeReloadConfig())
            } else {
                // Continue process next event in queue
                resetProcessingEventStatus()
                processEvent()
            }
        }
    }

}

// MARK: - Network Monitor

extension AnalyticsPublisher: NetworkMonitoringDelegate {
    func networkMonitorDidUpdate(isReady: Bool, isNetworkAvailable: Bool) {
        guard isReady else { return }
        flushInitialQueue()
    }

    private func flushInitialQueue() {
        let pendingEvents = initialQueue.getAndClear()
        guard !pendingEvents.isEmpty else { return }
        pendingEvents.forEach { event in
            publish(event)
        }
    }
}

// MARK: - Cache Management

extension AnalyticsPublisher {

    /** Clears all cached properties when receiving closed callback from socket. */
    private func clearEventsQueue(_ clearCachedIdentifyEvent: Bool) {
        if clearCachedIdentifyEvent {
            eventsQueue.clear()
            initialQueue.clear()
        }
    }

    /** Clears the cached identify event after it has been successfully sent */
    private func clearCachedIdentifyEvent() {
        storage.temporaryUser = nil
    }
}

// MARK: - Internal SDK events

extension AnalyticsPublisher {

    /**
     * Publishes internal SDK events through the socket.
     *
     * When socket is closed, for example return from background state
     * the SDK takes around 1-2 seconds to reconnect socket connection
     * in this period, if user close experience, the socket is not opened yet
     * then cache the event to resend when socket reopened.
     *
     * - Parameter sdkEvent: The SDK event to publish
     * - Parameter socketSubscription: Optional listener for socket events
     */
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        tryCatch {
            guard canRequestEvent else {
                cachedSDKEvents.append(sdkEvent)
                if socketManager.isAllowToOpenSocket { openSocket() }
                return
            }
            socketManager.publish(
                sdkEvent.eventName,
                payload: sdkEvent.eventPayload,
                isClosingSocket: isClosingSocket()
            )
        }
    }

    /** Process cached SDK events */
    private func processSDKEvent() {
        tryCatch {
            while !cachedSDKEvents.isEmpty && canRequestEvent {
                let sdkEvent = cachedSDKEvents.removeFirst()
                publishInternalSDKEvent(sdkEvent)
            }
        }
    }

    /**
     * Publishes a fake reload screen event when an experience is shown.
     * This ensures proper state tracking for experiences.
     *
     * - Parameter experienceType: The type of experience (FLOW or SURVEY)
     * - Parameter experienceId: The ID of the experience being shown
     */
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType? = nil,
        _ experienceId: Int? = nil,
        isFakeReload: Bool = true
    ) {
        tryCatch {
            guard canRequestEvent, eventsQueue.isEmpty() else { return }
            if let screenViewEntity {
                // update the seen content to make sure it contains the dismissed content that
                // trigger this fake reload
                experiencePublished(experienceType, experienceId)
                if eventThrottle.shouldThrottleScreenEvent(screenTitle: screenViewEntity.event.screenTitle ?? "") {
                    return
                }
                publishScreenEvent(isFakeReload: isFakeReload)
            }
        }
    }
}

// MARK: - Screen & Track events handling

extension AnalyticsPublisher {

    /// For experience which are come from start session
    var isStartSession: Bool {
        startSession
    }

    /// To return current screen entity
    var screenEntity: ScreenViewEntity? {
        screenViewEntity
    }

    private func publishScreenEvent(isFakeReload: Bool = false) {
        verifyScreenViewEntity()
        if let screenViewEntity {
            var payload: [String: Any] = [:]
            startSession = userSessionStateManager.getPostIdentificationStartSessionConfig(
                currentStartSession: startSession)
            payload[Constants.Analytics.screenTitleProperty] = screenViewEntity.event.screenTitle
            payload[Constants.Analytics.metaDataProperty] = [
                Constants.Analytics.isSessionStartedProperty: startSession,
                Constants.Analytics.fakeReload: isFakeReload,
                Constants.Analytics.seenContents: Array(screenViewEntity.seenExperiences),
                Constants.Analytics.seenSurveys: Array(screenViewEntity.seenSurveys)
            ]
            socketManager.publish(
                screenViewEntity.event.eventName,
                payload: payload,
                isClosingSocket: isClosingSocket()
            )
            if !isFakeReload {
                broadcastEvent(screenViewEntity.event, screenViewEntity.event.screenTitle ?? "", properties: nil)
            }
        }
    }

    /**
     A special case needed when come from logout state.
     In logout the app didn't execute setupScreenViewEntity, so after identify
     we have to request screen event to get experiences.
    */
    private func verifyScreenViewEntity() {
        // Early exit if we already have a screen view entity
        guard screenViewEntity == nil else { return }

        // Ensure user ID exists
        guard storage.userId.isNotEmpty else { return }

        // Get the current screen safely
        guard let currentScreen = experiencesPublisher?.getCurrentScreen,
            !currentScreen.isEmpty
        else { return }

        // Initialize screenViewEntity
        screenViewEntity = ScreenViewEntity(
            event: Event(type: .screen(currentScreen)),
            seenExperiences: screenViewEntity?.seenExperiences ?? Set(),
            seenSurveys: screenViewEntity?.seenSurveys ?? Set()
        )
    }

    /**
     * Updates the seen experiences when an experience is published/shown.
     *
     * - Parameter experienceType: The type of experience that was shown
     * - Parameter experienceId: The ID of the experience that was shown
     */
    internal func experiencePublished(_ experienceType: ExperienceType?, _ experienceId: Int?) {
        guard let experienceType, let experienceId else { return }
        if experienceType == .flow {
            screenViewEntity?.updateSeenFlowExperiences(experienceId)
        } else {
            screenViewEntity?.updateSeenSurveyExperiences(experienceId)
        }
    }

    // Act as cached identified event
    func getUserIdFromQueue() -> String? {
        eventsQueue.getFirst()?.userId
    }

    // Reset processing event state
    private func resetProcessingEventStatus() {
        isProcessingEvent.value = false
    }

    // To indicate close socket needs
    private func isClosingSocket() -> Bool {
        !(sessionMonitorer?.isAppActive ?? false)
    }

    /**
     * Compares the saved date with the current date and returns true if the difference is more than 30 minutes.
     * Updates startSession when comparing storage.sessionDate with current date if it's
     * more than 30 minutes.
     */
    func updateSessionState() {
        // No previous session saved — nothing to update
        guard let sessionDate = storage.sessionDate else { return }
        let elapsed = Date().timeIntervalSince(sessionDate)
        startSession = elapsed > Constants.Analytics.sessionDuration
        if startSession { experiencesPublisher?.resetState() }
    }

}

// MARK: - Event Broadcasting

extension AnalyticsPublisher {

    /**
     * Broadcasts events to analytics listeners for external consumption.
     *
     * - Parameter event: The event to broadcast
     * - Parameter value: The event value/identifier
     * - Parameter properties: The event payload data
     */
    func broadcastEvent(_ event: Event, _ value: String, properties: [String: Any]?) {
        performOn(.main) { [weak self] in
            self?.userpilot?.analyticsDelegate?.didTrack(
                analytic: event.userpilotAnalytic,
                value: value,
                properties: properties)
        }
    }

}
