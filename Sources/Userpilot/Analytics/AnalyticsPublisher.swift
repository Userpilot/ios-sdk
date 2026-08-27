//
//  AnalyticsPublishing.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `AnalyticsPublisher` handles the processing and dispatching of events to the backend.
//  Events flow through a serialized, ACK-gated queue: exactly one analytics event is in
//  flight at a time and the next one is sent only after the socket resolves the previous
//  push (ok, error, or timeout). Events are persisted to local storage while offline and
//  replayed as a `batch_events` payload when connectivity returns.
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
    func logout(clearCachedIdentifyEvent: Bool)

    /// check socket state
    var canRequestEvent: Bool { get }

    /// publish experience event
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// publish fake reload event
    /// - Returns: true when a screen push actually went out
    @discardableResult
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?,
        isFakeReload: Bool
    ) -> Bool

    /// update seen experiences
    func experiencePublished(
        _ experienceType: ExperienceType,
        _ experienceId: Int
    )

    /**
     * Returns whether the experience was already displayed on the current screen session.
     *
     * Flows use `seenExperiences`, Surveys use `seenSurveys`, and NPS returns `false` because NPS
     * is deduplicated by `ExperiencesPublisher` using its last tracked screen. The screen session
     * retains seen ids when the same screen is reported again and starts with empty sets when the
     * screen title changes.
     */
    func isExperienceSeen(_ experienceContent: ExperienceContent) -> Bool

    /// For experience which are come from start session
    var isStartSession: Bool { get }

    /// Current screen-session state.
    var screenSessionStateMachine: ScreenSessionStateMachine? { get }
}

extension AnalyticsPublishing {

    /// Fake reload requested by experience close/dismiss flows.
    @discardableResult
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?
    ) -> Bool {
        publishFakeReloadScreenEvent(experienceType, experienceId, isFakeReload: true)
    }
}

/**
 * AnalyticsPublisher is responsible for managing and publishing analytics events through WebSocket connections.
 *
 * This class handles:
 * - Serialized, ACK-gated event queuing and throttling
 * - Offline persistence and batch restore of events
 * - Socket connection management
 * - User identification and session management
 * - Screen tracking with experience state management
 * - Background/foreground state handling
 */
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

    /// Session monitoring to track app state
    private weak var sessionMonitorer: SessionMonitoring? {
        return container?.resolve(SessionMonitoring.self)
    }

    /// Push notification monitoring, used to re-assert the device token for a returning user.
    ///
    /// `AnalyticsPublishing` is registered *before* `PushNotificationMonitoring` in
    /// `initializeContainer()`, and `PushNotificationMonitor.init` resolves this publisher, so this
    /// must never be resolved from `init` — only on demand.
    private weak var pushNotificationMonitor: PushNotificationMonitoring? {
        return container?.resolve(PushNotificationMonitoring.self)
    }

    /// The screen name tracker.
    private let screenNameTracker: ScreenNameTracking

    /// Manages socket connections and event publishing over web socket.
    private let socketManager: SocketManaging

    /// Offline events handler for managing local storage and batch sending.
    private let offlineEventsHandler: OfflineEventsHandling

    /// Network monitor to check initial network readiness.
    private let networkMonitor: NetworkMonitoring

    /// The user session state machine.
    private let userSessionStateMachine: UserSessionStateManaging

    /// Once-per-screen policy for unchanged identify events and their push-token re-assert.
    private let identifyRefreshStateMachine = IdentifyRefreshStateMachine()

    // MARK: - Queues & State

    /// Internal SDK events cached while the socket is reconnecting. Responses are
    /// delivered to their senders via the multicast subscription, identified by
    /// `message.resolvedEvent` — no per-event callback is kept.
    private var cachedSDKEvents = [SDKEvent]()

    /// Event throttling mechanism to prevent spam
    private lazy var eventThrottle = EventThrottle(throttleDuration: 1.0)

    /**
     * Tracks the last screen viewed and the content seen during that screen session.
     */
    private(set) var screenSessionStateMachine: ScreenSessionStateMachine?

    /// Holds session start state - true indicates a new session should be started
    private var startSession = true

    /// Serialized live analytics event queue. The head stays enqueued until its
    /// socket ACK arrives (peek-then-dequeue-on-ACK), so a watchdog restart can
    /// re-attempt the same head without duplicating an acknowledged send.
    private lazy var eventsQueue = EventQueue()

    /// Holds events until the network monitor produces its first reliable state.
    private lazy var initialQueue = EventQueue()

    /// Single-flight gate: exactly one processing cycle may be in flight.
    private lazy var isProcessingEvent: AtomicReference<Bool> = AtomicReference(false)

    /// Watchdog for a stuck processing cycle (no socket callback arrived at all).
    private var processingWatchdog: DispatchWorkItem?

    /// Real-time queue for the watchdog, decoupled from event processing.
    private let watchdogQueue = DispatchQueue(
        label: Constants.DispatchQueues.analyticsWatchdog,
        qos: .utility
    )

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
        self.userSessionStateMachine = container.resolve(UserSessionStateManaging.self)
        self.screenNameTracker = container.resolve(ScreenNameTracking.self)
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
                    company: temporaryUser.company)
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
                    switch event.type {
                    case .identify:
                        _ = identify(event)
                    case .screen:
                        _ = screen(event)
                    case .event, .autoCaptureEvent:
                        _ = trackEvent(event)
                    }
                }
            }
            closeSocket()
            userSessionStateMachine.markUserBackFromBackground()
            resetProcessingEventStatus()
        }
    }

    /**
     * Clears all cached data and closes the socket connection.
     *
     * - Parameter clearCachedIdentifyEvent: If true, indicates this logout comes from app level,
     *        meaning the user is logged out and there is no new login. This will clear the
     *        push token from the backend. On user switch, the backend handles clearing the
     *        push token from the old user.
     */
    func logout(clearCachedIdentifyEvent: Bool = false) {
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
        // A new user starts with a fresh refresh allowance and owes no push-token sync
        identifyRefreshStateMachine.onUserChanged()
        // Reset content states
        experiencesPublisher?.logout()
        // Clear seen contents from screenSessionStateMachine
        screenSessionStateMachine?.resetState()
        // Clear all queues for app logout; on user switch keep them so the new
        // user's identify re-establishes the connection after the old channel closes
        clearAllCachedProperties(clearCachedIdentifyEvent)
        // Old-user offline events must never replay under a new user
        offlineEventsHandler.clearLocalEvents()
        // Close socket connection
        closeSocket()
    }

    /**
     * Resumes socket connection when app opens or returns from background.
     * This is the entry point that establishes socket connection.
     */
    func resume() {
        updateSessionState()
        if let userId = getUserIdFromQueue() { storage.userId = userId }
        // connect() gates itself on the socket state - always safe to call
        if storage.userId.isNotEmpty { openSocket() }
    }

    /**
     * Reset session state
     */
    func reset() {
        startSession = true
        eventThrottle.clear()
        identifyRefreshStateMachine.onUserChanged()
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
        startSession = difference > Constants.Analytics.sessionDuration
    }

    // MARK: - Publish Routing

    /**
     * Publishes an event to the server through the WebSocket connection.
     *
     * Routing order:
     * 1. Drop while the app is not active.
     * 2. Identify refresh policy (suppress / refresh once per screen / carries new data).
     * 3. Hold in `initialQueue` until network readiness is known (NWPathMonitor is async).
     * 4. Persist to local storage when the network is known unavailable.
     * 5. Drop during socket shutdown.
     * 6. Enqueue (throttled), then process or open the socket.
     *
     * - Parameter event: The event to be published.
     */
    func publish(_ event: Event) {
        publish(event, isInternalEvent: false)
    }

    func publish(_ event: Event, isInternalEvent: Bool) {
        tryCatch {
            var event = event

            // Keep experience targeting on the current screen immediately — events
            // queue now, and targeting must not lag behind navigation.
            if let screenTitle = event.screenTitle {
                experiencesPublisher?.updateScreen(screenTitle)
            }

            // Handle app state - drop events when app is not in active state
            guard sessionMonitorer?.isAppActive ?? false else { return }

            // Run identify events through the refresh policy. Non-identify events skip this.
            if event.isIdentifyEvent {
                let refreshDecision = handleIdentifyEvent(event)
                guard refreshDecision != .suppress else { return }
                if refreshDecision == .refresh {
                    event.isIdentifyRefresh = true
                }
            }

            // Hold events while network monitor is still resolving initial state
            if !networkMonitor.isReady {
                initialQueue.enqueue(event, isInternalEvent: isInternalEvent)
                return
            }

            // Network monitor is ready and reports no network: persist locally
            if offlineEventsHandler.shouldSaveOffline {
                handleOfflineEvent(event)
                return
            }

            // Check if socket is in shutdown state
            // For example: getting event while logging out, ignore the event
            guard !socketManager.isShutdownState else { return }

            // Valid state to process the event - add it to the events queue
            cacheEvent(event, isInternalEvent: isInternalEvent)

            // If socket is joining, the event waits in the queue until the
            // connection is established (drained from onSocketOpened)
            guard !socketManager.isJoiningSocket else { return }

            if canRequestEvent {
                processEvent()
            } else {
                handleClosedSocket(event)
            }
        }
    }

    /**
     * Persists an event to local storage while offline.
     * On an offline user switch the old user's stored events are cleared first,
     * because batch items carry no user id.
     */
    private func handleOfflineEvent(_ event: Event) {
        let isOfflineUserSwitch = isUserSwitchIdentifyEvent(event)

        // Android parity: once a different user is identified, every following
        // offline event belongs to that user, and old persisted events are cleared
        // before this identify is saved.
        if event.isIdentifyEvent, let userId = event.userId, !userId.isEmpty {
            storage.userId = userId
        }

        offlineEventsHandler.saveEventToLocalStorage(
            event: event,
            clearStoredEventsFirst: isOfflineUserSwitch
        )
    }

    /**
     * Builds the refresh request from the collaborators `IdentifyRefreshStateMachine` deliberately
     * does not own.
     *
     * - Parameter event: The identify event to classify
     * - Returns: The facts the refresh policy needs to decide
     */
    private func identifyRefreshRequest(for event: Event) -> IdentifyRefreshRequest {
        IdentifyRefreshRequest(
            carriesNoNewData: storage.user.isNotEmpty
                && User.fromJson(storage.user).isSameIdentifyEvent(event: event),
            isAnonymousUser: storage.anonymousUserId.isNotEmpty
                && event.userId == storage.anonymousUserId,
            // A pending identify has not reached the backend yet, so this is `onSocketClosed`
            // replaying it, not a fresh host-app call.
            isPendingReplay: storage.temporaryUser != nil && !socketManager.isSocketOpened
        )
    }

    /**
     * Runs an identify event through the refresh policy and, unless it is suppressed, caches it as
     * the pending identify event.
     *
     * - Parameter event: The identify event to handle
     * - Returns: The policy decision for this event
     */
    private func handleIdentifyEvent(_ event: Event) -> IdentifyRefreshDecision {
        let decision = identifyRefreshStateMachine.transition(identifyRefreshRequest(for: event))
        guard decision != .suppress else { return decision }

        // Update temporary cached user in storage
        storage.temporaryUser = event.toUser().toJson()

        return decision
    }

    /**
     * Handles events when socket is closed by attempting to open connection.
     *
     * - Parameter event: The event to handle
     */
    private func handleClosedSocket(_ event: Event) {
        // Update userId from cached identify event or current event
        updateUserIdFromEvent(event)

        // Only proceed if we have a valid userId.
        // This could be a valid case when user logged out and sent track or screen
        // event; in this case return and don't process the event, ignore it.
        guard !storage.userId.isEmpty else { return }

        openSocket()
    }

    /**
     * Updates the stored user ID from the event, prioritizing current event over cached identify event.
     *
     * - Parameter event: The event containing potential user ID
     */
    private func updateUserIdFromEvent(_ event: Event) {
        // When socket is closed then handle user session state
        if event.isIdentifyEvent {
            if storage.userId == event.userId {
                // Refresh identifies skip the post-identify fake-reload screen event
                if !event.isIdentifyRefresh {
                    userSessionStateMachine.markAwaitingInitialScreen()
                }
            } else {
                userSessionStateMachine.markUserSwitch()
            }
        }

        if let userId = event.userId, !userId.isEmpty {
            storage.userId = userId
        } else if let cachedUserId = getUserIdFromQueue() {
            storage.userId = cachedUserId
        }
    }

    private func isUserSwitchIdentifyEvent(_ event: Event?) -> Bool {
        guard let event else { return false }
        return event.isIdentifyEvent
            && storage.userId.isNotEmpty
            && event.userId != storage.userId
    }

    // MARK: - Serialized Event Processing

    /**
     * Processes the next unit of work, exactly one at a time.
     *
     * Priority order:
     * 1. Persisted offline events (restored and sent as one batch).
     * 2. Cached internal SDK events.
     * 3. The head of the live analytics queue.
     *
     * The head event is sent with a peek — it is dequeued only when its socket
     * ACK arrives in `onSocketEventSent`. The cycle is released by the socket
     * callbacks (ok/error/timeout), socket close, flush, or the watchdog.
     */
    private func processEvent() {
        tryCatch {
            // Single-flight gate: only one processing cycle may run
            guard isProcessingEvent.compareAndSet(expected: false, new: true) else { return }
            scheduleProcessingWatchdog()

            // Bail out when the socket can't accept events (e.g. a watchdog retry
            // after a disconnect) — publishing into a dead channel never resolves.
            // A half-open transport is recovered by SocketManager on the next
            // connect attempt. onSocketOpened restarts processing.
            guard canRequestEvent else {
                resetProcessingEventStatus()
                return
            }

            if isUserSwitchIdentifyEvent(eventsQueue.getFirst()) {
                offlineEventsHandler.clearLocalEvents()
            }

            if restoreOfflineEventsIfNeeded() {
                return
            }

            // Priority 2: sync internal SDK events directly
            processSDKEvent()

            // Priority 3: process the live queue head
            guard let event = eventsQueue.getFirst() else {
                handleEmptyEventQueue()
                return
            }

            // Nothing was pushed (throttled, invalid, or blocked): drop the head
            // and continue, otherwise the gate would wait for an ACK that will
            // never arrive.
            if !publishQueuedEvent(event) {
                skipHeadEvent()
            }
        }
    }

    /// Restores persisted offline events before live queue processing.
    private func restoreOfflineEventsIfNeeded() -> Bool {
        guard offlineEventsHandler.hasCachedEvents else { return false }
        offlineEventsHandler.restoreEventsFromLocalStorage { [weak self] in
            self?.resetProcessingEventStatus()
            self?.processEvent()
        }
        return true
    }

    /// Releases processing or sends the background fake reload when no live event is queued.
    private func handleEmptyEventQueue() {
        guard userSessionStateMachine.getCurrentState() == .backgroundToInitialScreen else {
            resetProcessingEventStatus()
            return
        }

        userSessionStateMachine.markNormal()
        if !publishFakeReloadScreenEvent(nil, nil, isFakeReload: false) {
            resetProcessingEventStatus()
        }
    }

    /// Publishes the queued event using the matching event-specific path.
    private func publishQueuedEvent(_ event: Event) -> Bool {
        switch event.type {
        case .identify:
            return identify(event)
        case .screen:
            return screen(event)
        case .event, .autoCaptureEvent:
            return trackEvent(event)
        }
    }

    /// Drops the queue head, releases the gate, and continues with the next event.
    private func skipHeadEvent() {
        eventsQueue.deleteFirst()
        resetProcessingEventStatus()
        processEvent()
    }

    /**
     * Caches an event into the serialized queue, throttling screen and track
     * events before they are enqueued.
     *
     * - Parameter event: The event to cache
     */
    private func cacheEvent(_ event: Event, isInternalEvent: Bool = false) {
        if storage.userId.isEmpty {
            eventsQueue.clear()
        }
        if event.isScreenEvent,
            eventThrottle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "") {
            return
        }
        switch event.type {
        case .event, .autoCaptureEvent:
            if eventThrottle.shouldThrottle(eventTitle: trackEventThrottleKey(event)) { return }
        default:
            break
        }
        eventsQueue.enqueue(event, isInternalEvent: isInternalEvent)
    }

    // MARK: - Event Senders

    /**
     * Identifies the user and handles the identify event.
     * If a new user ID is detected, it closes the socket and cleans up for user switching;
     * the queued identify is re-published from `onSocketClosed`.
     *
     * - Parameter event: The identify event containing user information
     * - Returns: true when a push went out or the switch is being handled asynchronously
     */
    private func identify(_ event: Event) -> Bool {
        guard let userId = event.userId else { return false }

        // If new user ID detected, close socket and clean up while it's connected
        if storage.userId.isNotEmpty && userId != storage.userId {
            // Mark as switch so the post-identify fake reload will be false
            userSessionStateMachine.markUserSwitch()
            userpilot?.clean()
            logout(clearCachedIdentifyEvent: false)
            return true
        }

        // Offline restore drops `isIdentifyRefresh`; re-detect same-user no-op identifies here.
        let isIdentifyRefresh = event.isIdentifyRefresh
            || (storage.user.isNotEmpty && User.fromJson(storage.user).isSameIdentifyEvent(event: event))

        var payload: [String: Any] = [
            Constants.Analytics.metaDataProperty: event.properties ?? [:]
        ]
        if let company = event.company, !company.isEmpty {
            payload[Constants.Analytics.identifyCompanyProperty] = company
        }
        socketManager.publish(event.eventName, payload: payload)

        if isIdentifyRefresh {
            // Nothing about the user changed, so the backend has nothing to re-evaluate:
            // send the identify alone and skip the fake reload screen event.
            syncPushTokenIfNeeded()
            return true
        }

        // Socket is connected with the same user id — request post-identify screen
        userSessionStateMachine.markAwaitingInitialScreen()
        return true
    }

    /**
     * Re-publishes the device push token owed by a forwarded identify refresh.
     *
     * `PushNotificationMonitor.setPushToken` only publishes when the token value changes, so a
     * returning user whose token is unchanged would otherwise never re-pair token ↔ user on the
     * backend. Called after the identify is on the wire so the backend sees the user first.
     */
    private func syncPushTokenIfNeeded() {
        // Check the socket first: the obligation must not be consumed while it cannot be fulfilled.
        guard canRequestEvent, identifyRefreshStateMachine.consumePushTokenSync() else { return }
        pushNotificationMonitor?.resyncPushToken()
    }

    /**
     * Processes and sends screen view events.
     *
     * - Parameter event: The screen event to process
     * - Returns: true when a screen push went out
     */
    private func screen(_ event: Event) -> Bool {
        // Returns true if this is a new screen, which triggers screen event
        if setupScreenEvent(event) {
            return publishScreenEvent(isFakeReload: false)
        }
        // Not a new screen, check if valid to trigger screen event
        if experiencesPublisher?.canRequestScreenEvent() == true {
            return publishScreenEvent(isFakeReload: false)
        }
        return false
    }

    /**
     * Sends track and auto-capture events with their full production payload
     * (metadata, screen context, and interaction event name).
     *
     * - Parameter event: The custom event to track
     * - Returns: true when a push went out
     */
    private func trackEvent(_ event: Event) -> Bool {
        var payload: [String: Any] = [:]
        payload[Constants.Analytics.eventNameProperty] =
            event.type == .autoCaptureEvent
            ? event.interactionEventName
            : event.eventTitle
        payload[Constants.Analytics.metaDataProperty] = event.properties ?? [:]
        if let screen = event.screen {
            payload[Constants.Analytics.screenProperty] = screen
        }
        if event.type == .autoCaptureEvent && event.screen == nil {
            logger.error("❗ Event Error, Auto capture event must have screen")
            return false
        }

        broadcastEvent(event, event.eventTitle, properties: payload)
        socketManager.publish(event.eventName, payload: payload)
        return true
    }

    // MARK: - Throttle Keys

    /**
     * Stable key for event throttling.
     * Non-AutoCapture events use `eventTitle`, or `eventName` when
     * the title is empty; autocapture uses screen + interaction/tab context.
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

        let rawInteraction = prop(Constants.AutoCapture.rawInteractionType)

        return [
            trackEventThrottleScreenName(from: event.screen),
            event.eventName,
            rawInteraction.isEmpty ? (event.interactionEventName ?? "") : rawInteraction,
            prop(Constants.AutoCapture.tabName),
            prop(Constants.AutoCapture.tabIndex),
            prop(Constants.AutoCapture.hierarchy),
            prop(Constants.AutoCapture.accessibilityIdentifier),
            prop(Constants.AutoCapture.dialogTitle),
            prop(Constants.AutoCapture.targetText),
            prop(Constants.AutoCapture.section),
            prop(Constants.AutoCapture.selectedIndex),
            prop(Constants.AutoCapture.selectedValue),
            prop(Constants.AutoCapture.placeholder),
            prop(Constants.AutoCapture.accessibilityLabel)
        ].joined(separator: "|")
    }

    /// Resolves a display class for throttling from `Event.screen` (set on autocapture events via `makeEvent`).
    private func trackEventThrottleScreenName(from screen: Payload) -> String {
        guard let screen, !screen.isEmpty else { return "" }
        if let name = screen[Constants.AutoCapture.screenClass] as? String, !name.isEmpty { return name }
        if let name = screen[Constants.AutoCapture.screenTitle] as? String, !name.isEmpty { return name }
        if let name = screen[Constants.AutoCapture.screenName] as? String, !name.isEmpty { return name }
        return ""
    }

    private func trackEventThrottleString(from value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    // MARK: - Screen Management

    /**
     * Sets up the screen event by updating the screen session state machine.
     *
     * If the screen title of the incoming event differs from the current screenSessionStateMachine's event:
     * - The startSession flag is set to false
     * - A new ScreenSessionStateMachine is created with an empty set of seen experiences
     *
     * If the screen title matches the current screenSessionStateMachine's event:
     * - A new ScreenSessionStateMachine is created, retaining the existing set of seen experiences
     *
     * - Parameter event: The new screen event to process
     * - Returns: true if this is a new screen, false if it's the same screen
     */
    @discardableResult
    private func setupScreenEvent(_ event: Event) -> Bool {
        var isNewScreen = false
        tryCatch {
            // Check if the screen title has changed
            let isScreenTitleChanged = screenSessionStateMachine?.event.screenTitle != event.screenTitle

            // Update session state if the screen title has changed
            if screenSessionStateMachine != nil && canRequestEvent && isScreenTitleChanged {
                startSession = false
            }

            // Update the screen session state and retain seen content when the screen did not change.
            if isScreenTitleChanged {
                isNewScreen = true

                // A genuinely new screen re-opens the identify refresh allowance
                identifyRefreshStateMachine.onScreenChanged()

                // New screen: start with an empty set of seen experiences
                screenSessionStateMachine = ScreenSessionStateMachine(
                    event: event,
                    seenExperiences: Set(),
                    seenSurveys: Set()
                )
            } else {
                // Same screen: retain the existing seen experiences
                screenSessionStateMachine = ScreenSessionStateMachine(
                    event: event,
                    seenExperiences: screenSessionStateMachine?.seenExperiences ?? Set(),
                    seenSurveys: screenSessionStateMachine?.seenSurveys ?? Set()
                )
            }
        }
        return isNewScreen
    }

}

// MARK: - Watchdog & Processing Gate

extension AnalyticsPublisher {

    /**
     * Schedules the stuck-cycle watchdog. Scheduled at the top of every claimed
     * processing cycle; cancelled by `resetProcessingEventStatus()` from every
     * socket resolution path.
     *
     * The interval is deliberately kept above the socket push timeout so socket
     * ok/error/timeout callbacks always resolve the in-flight event first — the
     * watchdog only fires when NO callback arrived at all (e.g. the push never
     * left because the channel wasn't ready).
     */
    private func scheduleProcessingWatchdog() {
        processingWatchdog?.cancel()

        let watchdog = DispatchWorkItem { [weak self] in
            guard let self, self.isProcessingEvent.value else { return }
            // Watchdog recovery for a stuck processing cycle.
            // If no socket resolution callback arrives (success, error, timeout, or close),
            // reset the processing gate and retry the current queue head.
            // This prevents the queue from stalling, but it is not a strict no-duplicate guarantee.
            self.logger.error("⏱️ Event processing stuck with no socket callback, restarting queue")
            self.resetProcessingEventStatus()
            self.processEvent()
        }

        processingWatchdog = watchdog
        watchdogQueue.asyncAfter(
            deadline: .now() + Constants.Analytics.stuckProcessingWatchdog,
            execute: watchdog
        )
    }

    /// Releases the single-flight gate and cancels the pending watchdog.
    private func resetProcessingEventStatus() {
        processingWatchdog?.cancel()
        processingWatchdog = nil
        isProcessingEvent.value = false
    }

}

// MARK: - Socket Subscription

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
     * Starts draining offline, SDK, and live queued events.
     */
    func onSocketOpened() {
        tryCatch {
            processEvent()
            // Cold start path: an identify refresh flushed when the socket opened may still owe
            // a push-token re-assert if identify() could not fulfill it yet.
            syncPushTokenIfNeeded()
        }
    }

    /**
     * Socket closed callback.
     * Handles user-switch reconnection: when the close came from switching users the
     * new user's identify is still at the head of the queue and is re-published here.
     */
    func onSocketClosed() {
        tryCatch {
            resetProcessingEventStatus()
            // Socket closed from error state, don't reopen, keep events for next open
            if socketManager.didCloseFromError { return }
            // Background close: keep the queue as-is (a queued new-user identify is
            // picked up by resume() on foreground). Re-publishing here would hit the
            // app-inactive guard and silently drop the event.
            guard sessionMonitorer?.isAppActive ?? false else { return }
            // Events still queued: the close came from a user switch, reopen the
            // socket keeping the identify event as the first event to process
            if let event = eventsQueue.dequeue() {
                userSessionStateMachine.markUserSwitch()
                publish(event, isInternalEvent: true)
            }
        }
    }

    /**
     * Callback triggered when a socket push resolves (ok, error, or timeout).
     * Dequeues the in-flight head, performs identify/screen bookkeeping, and
     * advances the queue. Error and timeout are at-most-once: the event is
     * dropped and the queue continues.
     */
    func onSocketEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ eventSent: Bool
    ) {
        tryCatch {
            // Only analytics events advance the queue - SDK/content events resolve
            // through their own direct subscriptions
            guard eventName.isAnalyticsEvent() else { return }

            // Remove the in-flight head - it stayed enqueued until this resolution
            let event = eventsQueue.dequeue()

            guard eventSent else {
                logger.error(
                    "⚠️ Event not acknowledged (%{public}@), dropping and continuing queue",
                    eventName)
                resetProcessingEventStatus()
                processEvent()
                return
            }

            // Update cached user object
            if let event, eventName == Constants.Event.identifyEvent && event.userId == storage.userId {
                var newUser = User.fromJson(storage.user)
                storage.user = newUser.updateUser(event: event).toJson() ?? ""
                logger.info("👤 USER %{public}@", storage.user)
                clearCachedIdentifyEvent()
                broadcastEvent(event, event.userId ?? "", properties: payload)
            }

            if eventName == Constants.Event.screenEvent {
                userSessionStateMachine.markNormal()
            }

            // Handle request screen event after user identify event
            if userSessionStateMachine.isPostIdentificationContext(eventName)
                && userSessionStateMachine.shouldRequestInitialScreenEvent(
                    eventsQueue.isEmpty(),
                    experiencesPublisher?.getCurrentScreen.isNotEmpty == true) {
                // Keep the gate claimed for the post-identify screen push, with a
                // fresh watchdog window for the new in-flight push
                scheduleProcessingWatchdog()
                let published = publishScreenEvent(
                    isFakeReload: userSessionStateMachine.getPostIdentificationFakeReloadConfig())
                if !published {
                    resetProcessingEventStatus()
                    processEvent()
                }
            } else {
                // Continue processing the next event in the queue
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

    /// Re-routes events held before the first network readiness through the
    /// normal publish routing (online queue or offline storage).
    private func flushInitialQueue() {
        let pendingEvents = initialQueue.getAndClear()
        guard !pendingEvents.isEmpty else { return }
        pendingEvents.forEach { event in
            publish(event)
        }
    }

}

// MARK: - Cache Management

private extension AnalyticsPublisher {

    /**
     * Clears all cached properties on app-level logout; user switch keeps them.
     *
     * - Parameter clearCachedIdentifyEvent: Whether to clear the cached identify event
     */
    private func clearAllCachedProperties(_ clearCachedIdentifyEvent: Bool = false) {
        guard clearCachedIdentifyEvent else { return }
        eventsQueue.clear()
        initialQueue.clear()
        cachedSDKEvents.removeAll()
        self.clearCachedIdentifyEvent()
    }

    /** Clears the cached identify event after it has been successfully sent */
    private func clearCachedIdentifyEvent() {
        storage.temporaryUser = nil
    }
}

// MARK: - Internal SDK Events

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

    /**
     * Checks the current screen's type-specific seen set for the supplied experience.
     *
     * A Flow id is checked only in `seenExperiences`, and a Survey id only in `seenSurveys`, so a
     * Flow and Survey sharing a numeric id stay distinct. NPS always returns `false` here and
     * continues through the existing per-screen NPS deduplication in `ExperiencesPublisher`.
     * With no screen session yet, Flow and Survey are treated as unseen.
     */
    func isExperienceSeen(_ experienceContent: ExperienceContent) -> Bool {
        switch experienceContent {
        case .flow(let content):
            return screenSessionStateMachine?.seenExperiences.contains(content.id) == true
        case .survey(let content):
            return screenSessionStateMachine?.seenSurveys.contains(content.id) == true
        case .nps:
            // NPS deduplication is managed by ExperiencesPublisher per screen.
            return false
        }
    }

    /**
     * Publishes internal SDK events through the socket.
     *
     * When the socket is closed — for example returning from background the SDK
     * takes 1-2 seconds to reconnect — the event is cached and re-sent from
     * `processEvent` once the socket reopens. Responses reach their senders via
     * the multicast subscription, identified by `message.resolvedEvent`.
     *
     * - Parameter sdkEvent: The SDK event to publish
     */
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        tryCatch {
            guard canRequestEvent else {
                cachedSDKEvents.append(sdkEvent)
                // connect() gates itself on the socket state - always safe to call
                openSocket()
                return
            }
            socketManager.publish(
                sdkEvent.eventName,
                payload: sdkEvent.eventPayload
            )
        }
    }

    /** Sends any cached SDK events while the socket can accept them */
    private func processSDKEvent() {
        tryCatch {
            while !cachedSDKEvents.isEmpty && canRequestEvent {
                let sdkEvent = cachedSDKEvents.removeFirst()
                publishInternalSDKEvent(sdkEvent)
            }
        }
    }

    /**
     * Publishes a fake reload screen event when an experience is shown/closed.
     * This ensures proper state tracking for experiences.
     *
     * - Parameter experienceType: The type of experience (FLOW or SURVEY)
     * - Parameter experienceId: The ID of the experience being shown
     * - Parameter isFakeReload: false when this is a real screen refresh (back from background)
     */
    @discardableResult
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?,
        isFakeReload: Bool
    ) -> Bool {
        var published = false
        tryCatch {
            // Never bypass queue ordering: a fake reload only goes out when no
            // live analytics event is queued or in flight
            guard canRequestEvent, eventsQueue.isEmpty() else { return }
            guard let screenSessionStateMachine else { return }

            // Update the seen content to make sure it contains the dismissed
            // content that triggered this fake reload
            if let experienceType, let experienceId {
                experiencePublished(experienceType, experienceId)
            }
            if eventThrottle.shouldThrottleScreenEvent(
                screenTitle: screenSessionStateMachine.event.screenTitle ?? "") {
                return
            }
            published = publishScreenEvent(isFakeReload: isFakeReload)
        }
        return published
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
            screenSessionStateMachine?.updateSeenFlowExperiences(experienceId)
        } else {
            screenSessionStateMachine?.updateSeenSurveyExperiences(experienceId)
        }
    }

}

// MARK: - Screen Event Publishing

extension AnalyticsPublisher {

    /**
     * Publishes the current screen session state as a screen event, carrying
     * session-start state, fake-reload flag, and seen experiences/surveys.
     *
     * - Returns: true when a screen push went out
     */
    @discardableResult
    private func publishScreenEvent(isFakeReload: Bool = false) -> Bool {
        ensureScreenSessionStateMachine()
        guard let screenSessionStateMachine else { return false }

        let screenEvent = screenSessionStateMachine.event
        if let screenTitle = screenEvent.screenTitle {
            if shouldSyncManualScreenForInteractionPayload() {
                screenNameTracker.updateScreen(
                    with: ScreenTrackingPayload(
                        screenTitle: screenTitle,
                        appFramework: config.appFramework
                    )
                )
            }
            experiencesPublisher?.updateScreen(screenTitle)
        }

        // For a user switch the post-identification screen must force a new session
        startSession = userSessionStateMachine.getPostIdentificationStartSessionConfig(
            currentStartSession: startSession)

        var payload: [String: Any] = [:]
        payload[Constants.Analytics.screenTitleProperty] = screenEvent.screenTitle ?? ""

        let existingMetadata = screenEvent.properties ?? [:]
        let newMetadata: [String: Any] = [
            Constants.Analytics.isSessionStartedProperty: startSession,
            Constants.Analytics.fakeReload: isFakeReload,
            Constants.Analytics.seenContents: Array(screenSessionStateMachine.seenExperiences),
            Constants.Analytics.seenSurveys: Array(screenSessionStateMachine.seenSurveys)
        ]
        payload[Constants.Analytics.metaDataProperty] =
            existingMetadata.merging(newMetadata) { _, new in new }

        socketManager.publish(screenEvent.eventName, payload: payload)

        if isFakeReload {
            suppressScreenAutocaptureAfterFakeReload()
        } else {
            broadcastEvent(screenEvent, screenEvent.screenTitle ?? "", properties: nil)
        }
        return true
    }

    /// Whether a manually published screen should update `ScreenNameTracker` so
    /// subsequent interaction autocapture events carry the correct screen context.
    private func shouldSyncManualScreenForInteractionPayload() -> Bool {
        if config.isWrapperSDK {
            return !config.isWrapperScreenAutoCaptureEnabled &&
                config.isWrapperInteractionAutoCaptureEnabled
        }
        return !config.enableScreenAutoCapture && config.enableInteractionAutoCapture
    }

    /**
     A special case needed when coming from a logout state.
     In logout the app didn't execute setupScreenEvent, so after identify
     we have to request a screen event to get experiences.
    */
    private func ensureScreenSessionStateMachine() {
        // Early exit if we already have a screen session state machine.
        guard screenSessionStateMachine == nil else { return }

        // Ensure user ID exists
        guard storage.userId.isNotEmpty else { return }

        // Get the current screen safely
        guard let currentScreen = experiencesPublisher?.getCurrentScreen,
            !currentScreen.isEmpty
        else { return }

        // Initialize the screen session state machine.
        screenSessionStateMachine = ScreenSessionStateMachine(
            event: Event(type: .screen(currentScreen)),
            seenExperiences: Set(),
            seenSurveys: Set()
        )
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

    /// Acts as the cached identify event: the pending identify still in the queue.
    func getUserIdFromQueue() -> String? {
        eventsQueue.find(where: { $0.isIdentifyEvent })?.userId
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

#if DEBUG
extension AnalyticsPublisher {
    func mockGetEventsToFlush() -> [Event] {
        return eventsQueue.getAll()
    }

    func mockGetInitialQueue() -> [Event] {
        return initialQueue.getAll()
    }

    func mockIdentifyRefreshState() -> IdentifyRefreshStateMachine.State {
        return identifyRefreshStateMachine.state
    }
}
#endif
// swiftlint:enable file_length
