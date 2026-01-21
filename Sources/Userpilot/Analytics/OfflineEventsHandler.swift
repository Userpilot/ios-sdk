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
    func saveEventToLocalStorage(event: Event)

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
        label: "com.userpilot.offlineevents",
        qos: .utility
    )

    /// Session monitoring to track app state.
    private weak var sessionMonitorer: SessionMonitoring? {
        return container?.resolve(SessionMonitoring.self)
    }

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
    func saveEventToLocalStorage(event: Event) {
        tryCatch {
            // In case the user deleted the app cache or storage
            let userId = storage.userId
            guard !userId.isEmpty else { return }

            // Create event storage from event
            guard let eventStorage = EventStorage(event, config.token, userId) else {
                logger.error("⚠️ Failed to encode event to JSON")
                return
            }

            // Save this item to local storage so we can retry later if needed
            eventDatabaseStorage.saveEvent(
                eventStorage,
                completion: { [weak self] saved in
                    if saved {
                        self?.logger.info(
                            "🗃️ Event saved to local storage: %{public}@", event.eventName)
                    } else {
                        self?.logger.error("⚠️ Event not saved - storage limit exceeded")
                    }
                })
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
                            guard let event = eventStorage.toEvent() else {
                                self.logger.error("⚠️ Failed to decode event from local storage")
                                continue
                            }

                            var eventData: [String: Any]?

                            switch event.type {
                            case .identify:
                                eventData = self.buildIdentifyEventData(
                                    event: event, eventStorage: eventStorage)
                            case .screen:
                                eventData = self.buildScreenEventData(
                                    event: event, eventStorage: eventStorage)
                            case .event:
                                eventData = self.buildTrackEventData(
                                    event: event, eventStorage: eventStorage)
                            }

                            if let eventData = eventData {
                                eventsList.append(eventData)
                            }
                        }

                        if !eventsList.isEmpty {
                            // Store completion to be called after socket sends the batch
                            self.offlineRestoreCompletion = completion

                            let batchPayload: [String: Any] = ["events": eventsList]
                            self.socketManager.publish(
                                Constants.Event.batchEventsEvent,
                                payload: batchPayload,
                                isClosingSocket: self.isClosingSocket()
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
        eventData[Constants.Analytics.eventNameProperty] = event.eventTitle
        eventData[Constants.Analytics.metaDataProperty] = event.properties ?? [:]

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

    private func isClosingSocket() -> Bool {
        !(sessionMonitorer?.isAppActive ?? false)
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
            logger.info("✅ Offline batch events sent successfully")
            if let completion = offlineRestoreCompletion {
                offlineRestoreCompletion = nil
                completion()
            }
        }
    }

}
// swiftlint:enable all
