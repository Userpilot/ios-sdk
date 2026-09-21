//
//  OfflineEventsHandler.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 02/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Manages offline event storage and retrieval for the Userpilot SDK.
//  This handler is responsible for saving events to local storage when network is unavailable,
//  restoring events when connection is re-established, and batch-sending them.
//

import Foundation

// MARK: - OfflineEventsHandling Protocol

// swiftlint:disable all
internal protocol OfflineEventsHandling: AnyObject {
    /// Checks if events should be saved offline due to network unavailability
    var shouldSaveOffline: Bool { get }

    /// Fast check to determine if there are cached events in local storage
    var hasCachedEvents: Bool { get }

    /// Saves an event to local storage when network is unavailable
    /// - Parameter clearStoredEventsFirst: Set on an offline user switch — batch items
    ///   carry no user id, so the old user's stored events must not be replayed
    ///   under the new user.
    func saveEventToLocalStorage(event: Event, clearStoredEventsFirst: Bool)

    /// Saves an internal SDK event to local storage when network is unavailable.
    ///
    /// Unlike `saveEventToLocalStorage` there is no `clearStoredEventsFirst`: an internal
    /// event is never an identify event, so an offline user switch cannot arrive here.
    func saveSDKEventToLocalStorage(_ sdkEvent: SDKEvent)

    /// Restores events from local storage and publishes them as a batch
    /// - Parameter completion: Optional callback invoked when restoration is complete
    func restoreEventsFromLocalStorage(completion: (() -> Void)?)

    /// Clears all events from local storage
    func clearLocalEvents()
}

// MARK: - OfflineEventsHandler

/// Manages offline event storage and retrieval for the Userpilot SDK.
///
/// This handler is responsible for:
/// - Saving events to local storage when network is unavailable
/// - Restoring events from local storage when connection is re-established
/// - Clearing local events when necessary (user switch, logout, etc.)
///
/// The handler ensures events are not lost during network outages by persisting them locally and
/// batch-sending them once the connection is available.
internal class OfflineEventsHandler: OfflineEventsHandling {

    // MARK: - Properties

    /// A weak reference to ExperienceRendering would be expected here to avoid a retain cycle with AnalyticsPublisher
    private weak var container: DIContainer?
    private let config: Userpilot.Config
    private let storage: DataStoring
    private let networkMonitor: NetworkMonitoring
    private let socketManager: SocketManaging
    private let eventDatabaseStorage: EventStoring
    private let logger: Logging

    /// Serial background queue for processing offline events
    private let offlineEventsQueue = DispatchQueue(
        label: Constants.DispatchQueues.offlineEvents,
        qos: .utility
    )

    /// Completion callback to be invoked after offline events are sent
    private var offlineRestoreCompletion: (() -> Void)?

    // MARK: - Initialization

    init(container: DIContainer) {
        self.container = container
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.networkMonitor = container.resolve(NetworkMonitoring.self)
        self.socketManager = container.resolve(SocketManaging.self)
        self.eventDatabaseStorage = container.resolve(EventStoring.self)
        self.logger = config.logger

        // Register as socket subscription listener
        self.socketManager.registerCallback(self)
    }

    // MARK: - OfflineEventsHandling

    /// Checks if network is available for sending events.
    /// - Returns: true if network is unavailable and events should be saved offline
    var shouldSaveOffline: Bool {
        return !networkMonitor.isNetworkAvailable && networkMonitor.isReady
    }

    /// Fast check to determine if there are cached events in local storage.
    /// This is optimized for performance using a simple count query.
    /// - Returns: true if there are stored events, false otherwise
    var hasCachedEvents: Bool {
        return eventDatabaseStorage.hasEvents()
    }

    /**
     * Saves an event to local storage when network is unavailable.
     *
     * This method serializes the event and stores it in the local database for later retrieval when
     * network becomes available.
     *
     * - Parameter event: The event to save to local storage
     */
    func saveEventToLocalStorage(event: Event, clearStoredEventsFirst: Bool = false) {
        tryCatch {
            // Prefer the stored user id, fall back to the event's own (covers an
            // offline identify arriving before storage.userId is set).
            let userId = storage.userId.isNotEmpty ? storage.userId : (event.userId ?? "")
            guard !userId.isEmpty else { return }

            // Offline user switch: drop the previous user's stored events first.
            if clearStoredEventsFirst {
                eventDatabaseStorage.deleteAllEvents()
            }

            // Create event storage from event
            guard let eventStorage = EventStorage(event, config.token, userId) else {
                logger.error("⚠️ Failed to encode event to JSON")
                return
            }

            // Save this item to local storage so we can retry later if needed
            persistOfflineEvent(
                eventStorage,
                eventName: event.eventName,
                successMessage: "🗃️ Event saved to local storage: %{public}@",
                limitMessage: "⚠️ Event not saved - storage limit exceeded")
        }
    }

    /**
     * Saves an internal SDK event to local storage when network is unavailable.
     *
     * The event is wrapped in a `StoredOfflineEvent` envelope marked `.internalEvent` so the
     * replay path can tell it apart from an analytics row.
     *
     * There is deliberately no `clearStoredEventsFirst` counterpart to
     * `saveEventToLocalStorage`: an internal event is never an identify event, so an offline
     * user switch cannot arrive through this path. An `SDKEvent` also carries no user id of
     * its own, so an empty `storage.userId` drops the event rather than falling back.
     *
     * - Parameter sdkEvent: The internal SDK event to save to local storage
     */
    func saveSDKEventToLocalStorage(_ sdkEvent: SDKEvent) {
        tryCatch {
            let userId = storage.userId
            guard !userId.isEmpty else { return }

            guard let eventStorage = EventStorage(
                StoredOfflineEvent(sdkEvent: sdkEvent), config.token, userId
            ) else {
                logger.error("⚠️ Failed to encode internal event to JSON")
                return
            }

            persistOfflineEvent(
                eventStorage,
                eventName: sdkEvent.eventName,
                successMessage: "🗃️ Internal event saved to local storage: %{public}@",
                limitMessage: "⚠️ Internal event not saved - storage limit exceeded")
        }
    }

    /*
     * Restores events from local storage and publishes them as a batch.
     *
     * This method is called when:
     * - Socket connection is established
     * - Network becomes available
     * - Event queue is empty
     *
     * Events are sent as a single batch request to minimize socket overhead.
     * The entire operation runs on a dedicated serial background queue.
     *
     * - Parameter completion: Optional callback invoked when restoration and sending is complete
     */
    func restoreEventsFromLocalStorage(completion: (() -> Void)? = nil) {
        offlineEventsQueue.async(flags: .barrier) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            tryCatch {
                // getAllEventsAndDelete already runs on its own background queue
                self.eventDatabaseStorage.getAllEventsAndDelete { [weak self] localEvents in
                    guard let self else {
                        completion?()
                        return
                    }

                    if localEvents.isEmpty {
                        completion?()
                        return
                    }

                    self.logger.info(
                        "🗃️ Restoring %{public}d events from local storage", localEvents.count)

                    // Process events on our serial queue (heavy operation)
                    self.offlineEventsQueue.async { [weak self] in
                        guard let self else {
                            completion?()
                            return
                        }

                        var eventsList: [[String: Any]] = []

                        for eventStorage in localEvents {
                            guard let stored = eventStorage.toStoredEvent(), stored.isSupportedSchema else {
                                self.logger.error("⚠️ Failed to decode event from local storage")
                                continue
                            }

                            var eventData: [String: Any]?

                            // The internal check comes first: an internal row's `eventType`
                            // carries the SDK event name, not an analytics event name, so it
                            // must never reach a `switch event.type` branch.
                            if stored.isInternalEvent {
                                eventData = self.buildInternalEventData(
                                    stored: stored, eventStorage: eventStorage)
                            } else if let event = stored.event {
                                switch event.type {
                                case .identify:
                                    eventData = self.buildIdentifyEventData(
                                        event: event, eventStorage: eventStorage)
                                case .screen:
                                    eventData = self.buildScreenEventData(
                                        event: event, eventStorage: eventStorage)
                                case .event, .autoCaptureEvent:
                                    eventData = self.buildTrackEventData(
                                        event: event, eventStorage: eventStorage)
                                }
                            } else {
                                // Decoded cleanly but carries neither an internal payload nor an
                                // analytics event — nothing this version knows how to replay.
                                self.logger.error(
                                    "⚠️ Dropping unsupported offline event: %{public}@", stored.eventType)
                            }

                            if let eventData = eventData {
                                eventsList.append(eventData)
                            }
                        }

                        if !eventsList.isEmpty {
                            // Store completion to be called after socket sends the batch
                            self.offlineRestoreCompletion = completion

                            let batchPayload: [String: Any] = [
                                Constants.OfflineEvents.eventsProperty: eventsList
                            ]
                            self.socketManager.publish(
                                Constants.Event.batchEventsEvent,
                                payload: batchPayload
                            )
                            self.logger.info(
                                "🗃️ Restored %{public}d events from local storage as batch",
                                eventsList.count
                            )
                        } else {
                            completion?()
                        }
                    }
                }
            }
        }
    }

    /**
     * Clears all events from local storage.
     *
     * This method is called when:
     * - User logs out
     * - User switches to a different account
     * - SDK is reset
     */
    func clearLocalEvents() {
        eventDatabaseStorage.deleteAllEvents()
    }

    // MARK: - Private Methods

    /**
     * Persists an already-encoded row and reports the outcome.
     *
     * Shared tail of `saveEventToLocalStorage` and `saveSDKEventToLocalStorage`. The two differ
     * in how they resolve the user id and build the row; they do not differ in how the row is
     * persisted or in the shape of the outcome logging, so a future change to the
     * persistence-failure path (a retry, a metric, a dropped-event counter) only has to be made
     * here.
     *
     * `Logging` declares its messages as `StaticString`, so the two log lines cannot be built at
     * runtime and are passed in as literals instead — the same way `UPLogger` threads its own
     * `StaticString` format down into `os_log`.
     *
     * - Parameters:
     *   - eventStorage: The encoded row to persist
     *   - eventName: Event name interpolated into `successMessage`
     *   - successMessage: Logged at `info` level when the row was stored
     *   - limitMessage: Logged at `error` level when the store refused the row
     */
    private func persistOfflineEvent(
        _ eventStorage: EventStorage,
        eventName: String,
        successMessage: StaticString,
        limitMessage: StaticString
    ) {
        eventDatabaseStorage.saveEvent(
            eventStorage,
            completion: { [weak self] saved in
                if saved {
                    self?.logger.info(successMessage, eventName)
                } else {
                    self?.logger.error(limitMessage)
                }
            })
    }

    /**
     * Builds event data map for identify events.
     *
     * - Parameters:
     *   - event: The identify event
     *   - eventStorage: The stored event metadata
     * - Returns: Map containing event data for batch sending
     */
    private func buildIdentifyEventData(
        event: Event,
        eventStorage: EventStorage
    ) -> [String: Any] {
        var eventData: [String: Any] = [:]
        eventData[Constants.OfflineEvents.eventTypeProperty] = event.eventName
        eventData[Constants.OfflineEvents.createdAtProperty] = formatTimestampWithTimezone(
            eventStorage.createdAt)
        eventData[Constants.Analytics.metaDataProperty] = event.properties ?? [:]

        if let company = event.company, !company.isEmpty {
            eventData[Constants.Analytics.identifyCompanyProperty] = company
        }

        return eventData
    }

    /**
     * Builds event data map for screen events.
     *
     * - Parameters:
     *   - event: The screen event
     *   - eventStorage: The stored event metadata
     * - Returns: Map containing event data for batch sending
     */
    private func buildScreenEventData(
        event: Event,
        eventStorage: EventStorage
    ) -> [String: Any] {
        var eventData: [String: Any] = [:]
        eventData[Constants.OfflineEvents.eventTypeProperty] = event.eventName
        eventData[Constants.OfflineEvents.createdAtProperty] = formatTimestampWithTimezone(
            eventStorage.createdAt)
        eventData[Constants.Analytics.screenTitleProperty] = event.screenTitle ?? ""
        eventData[Constants.Analytics.metaDataProperty] = [Constants.Analytics.fakeReload: false]
        return eventData
    }

    /**
     * Builds event data map for track events.
     *
     * - Parameters:
     *   - event: The track event
     *   - eventStorage: The stored event metadata
     * - Returns: Map containing event data for batch sending
     */
    private func buildTrackEventData(
        event: Event,
        eventStorage: EventStorage
    ) -> [String: Any] {
        var eventData: [String: Any] = [:]
        eventData[Constants.OfflineEvents.eventTypeProperty] = event.eventName
        eventData[Constants.OfflineEvents.createdAtProperty] = formatTimestampWithTimezone(
            eventStorage.createdAt)
        // Auto-capture events carry the backend-facing interaction name; plain
        // track events use their title (Android batch parity).
        eventData[Constants.Analytics.eventNameProperty] =
            event.interactionEventName ?? event.eventTitle
        eventData[Constants.Analytics.metaDataProperty] = event.properties ?? [:]
        if let screen = event.screen {
            eventData[Constants.Analytics.screenProperty] = screen
        }

        return eventData
    }

    /**
     * Builds event data map for an internal SDK event.
     *
     * The event's own payload is spread at the top level rather than nested under
     * `metaDataProperty`: internal payloads are flat maps of JSON primitives and none of them
     * carry a key that could collide with `eventTypeProperty` or `createdAtProperty`. The
     * Android SDK's `buildInternalEventData` produces the same shape, so this is a
     * cross-platform wire contract — do not rename keys or nest the payload.
     *
     * - Parameters:
     *   - stored: The stored internal event
     *   - eventStorage: The stored event metadata
     * - Returns: Map containing event data for batch sending
     */
    private func buildInternalEventData(
        stored: StoredOfflineEvent,
        eventStorage: EventStorage
    ) -> [String: Any] {
        var eventData: [String: Any] = [:]
        eventData[Constants.OfflineEvents.eventTypeProperty] = stored.eventType
        eventData[Constants.OfflineEvents.createdAtProperty] = formatTimestampWithTimezone(
            eventStorage.createdAt)
        for (key, value) in stored.payload ?? [:] {
            eventData[key] = value
        }
        return eventData
    }

    /**
     * Formats a timestamp (in milliseconds) to ISO-8601 format with timezone information.
     *
     * - Parameter timestampMillis: The timestamp in milliseconds since epoch
     * - Returns: ISO-8601 formatted string with timezone (e.g., "2025-10-28T14:30:00.000+03:00")
     */
    private func formatTimestampWithTimezone(_ timestampMillis: TimeInterval) -> String {
        // Convert milliseconds to seconds for Date initialization
        let date = Date(timeIntervalSince1970: timestampMillis / 1_000.0)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

}

// MARK: - SocketSubscription

extension OfflineEventsHandler: SocketSubscription {

    /// Handles socket event sent and manages offline batch event completion
    func onSocketEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ eventSent: Bool
    ) {
        if eventName == Constants.Event.batchEventsEvent {
            // Locked policy (release/Android parity): events were already deleted
            // before the send, so the restore completes on ANY resolution —
            // ok, error, or timeout. A failed batch is accepted at-most-once loss.
            if eventSent {
                logger.info("✅ Offline batch events sent successfully")
            } else {
                logger.error("⚠️ Offline batch events send failed or timed out")
            }
            if let completion = offlineRestoreCompletion {
                offlineRestoreCompletion = nil
                completion()
            }
        }
    }

}
// swiftlint:enable all
