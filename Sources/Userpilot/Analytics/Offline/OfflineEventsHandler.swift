//
//  OfflineEventsHandler.swift
//  Userpilot SDK
//
//  Created by Userpilot on 02/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Manages offline event storage and retrieval for the Userpilot SDK.
//  This handler is responsible for saving events to local storage when network is unavailable,
//  restoring events when connection is re-established, and batch-sending them.
//

import Foundation

// MARK: - OfflineEventsHandling Protocol

internal protocol OfflineEventsHandling: AnyObject {
    /// Checks if events should be saved offline due to network unavailability
    var shouldSaveOffline: Bool { get }

    /// Fast check to determine if there are cached events in local storage
    var hasCachedEvents: Bool { get }

    /// Saves an admitted event to local storage when network is unavailable.
    func saveEventToLocalStorage(event: Event)

    /// Saves an internal SDK event to local storage when network is unavailable.
    func saveSDKEventToLocalStorage(_ sdkEvent: SDKEvent)

    /// Restores events from local storage and publishes them as a batch
    /// - Parameter completion: Optional callback invoked when restoration is complete
    func restoreEventsFromLocalStorage(completion: (() -> Void)?)

    /// Abandons a restore without deleting rows still in the database.
    func cancelRestore()

    /// Cancels the current restore and clears all events from local storage.
    func clearLocalEvents()
}

extension OfflineEventsHandling {
    func cancelRestore() {}
}

// MARK: - OfflineEventsHandler

/// Saves admitted events and restores one user-bound batch before live analytics resumes.
///
/// The database orders persistence; `offlineEventsQueue` decodes rows. `restoreLock` owns only
/// the active restore and its completion, so logout/switch can invalidate pending work synchronously.
internal class OfflineEventsHandler: OfflineEventsHandling {

    // MARK: - Properties

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

    /// Only the lock accesses ownership and completion. Decoding stays off the caller's queue.
    private final class RestoreOperation {
        let userID: String
        var completion: (() -> Void)?

        init(userID: String, completion: (() -> Void)?) {
            self.userID = userID
            self.completion = completion
        }
    }
    private let restoreLock = NSLock()
    private var restore: RestoreOperation?

    // MARK: - Initialization

    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.networkMonitor = container.resolve(NetworkMonitoring.self)
        self.socketManager = container.resolve(SocketManaging.self)
        self.eventDatabaseStorage = container.resolve(EventStoring.self)
        self.logger = config.logger
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

    /// Capture the user before persistence, falling back to an offline identify's own user ID.
    func saveEventToLocalStorage(event: Event) {
        tryCatch {
            // Prefer the stored user id, fall back to the event's own (covers an
            // offline identify arriving before storage.userId is set).
            let userId = storage.userId.isNotEmpty ? storage.userId : (event.userId ?? "")
            guard !userId.isEmpty else { return }

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

    /// SDK events have no user ID fallback; keep their payload flat in the stored envelope.
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

    /// Snapshot the user and read/delete rows in database order. Completion runs after batch ACK
    /// (or an empty batch), on the existing worker/callback queue; cancelled restores stay silent.
    func restoreEventsFromLocalStorage(completion: (() -> Void)? = nil) {
        let operation = RestoreOperation(userID: storage.userId, completion: completion)
        let queue = offlineEventsQueue
        restoreLock.withLock {
            restore = operation
            // Both database operations only enqueue work. Submit the read under the same lock as
            // clear's delete so a cancelled read cannot be submitted after a new user's saves.
            eventDatabaseStorage.getAllEventsAndDelete { [weak self] localEvents in
                queue.async { [weak self] in
                    self?.decode(localEvents, for: operation)
                }
            }
        }
    }

    /// Decode off the database queue; abandoned restores cannot submit a decoded batch.
    private func decode(_ localEvents: [EventStorage], for operation: RestoreOperation) {
        guard isCurrent(operation) else { return }
        var events: [[String: Any]] = []
        for row in localEvents {
            guard isCurrent(operation) else { return }
            guard !operation.userID.isEmpty, row.userId == operation.userID,
                  let payload = row.toStoredEvent()?.toBatchPayload(createdAt: row.createdAt) else { continue }
            events.append(payload)
        }
        submit(events, for: operation)
    }

    /// Keep the restore active until its own success, error or timeout releases the analytics queue.
    private func submit(_ events: [[String: Any]], for operation: RestoreOperation) {
        guard !events.isEmpty else { finishRestore(operation); return }
        // The predicate also covers cancellation after decoding but before transport submission.
        socketManager.publish(
            Constants.Event.batchEventsEvent,
            payload: [Constants.OfflineEvents.eventsProperty: events], userID: operation.userID,
            shouldSend: { [weak self] in self?.isCurrent(operation) == true },
            completion: { [weak self] _, success in
                self?.didSend(operation, success: success)
            })
        logger.info("🗃️ Prepared %{public}d offline events as batch", events.count)
    }

    private func isCurrent(_ operation: RestoreOperation) -> Bool {
        restoreLock.withLock { restore === operation }
    }

    private func finishRestore(_ operation: RestoreOperation) {
        let completion: (() -> Void)? = restoreLock.withLock {
            guard restore === operation else { return nil }
            restore = nil
            let completion = operation.completion
            operation.completion = nil
            return completion
        }
        completion?() // Never call back into the publisher or database while holding the lock.
    }

    func cancelRestore() {
        restoreLock.withLock {
            restore = nil
        }
    }

    /// Invalidate synchronously, including a decoded batch waiting to run on main, then delete rows.
    func clearLocalEvents() {
        restoreLock.withLock {
            restore = nil
            eventDatabaseStorage.deleteAllEvents()
        }
    }

    // MARK: - Private Methods

    /// Analytics and internal rows share persistence while retaining their existing log formats.
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

}

// MARK: - Batch completion

extension OfflineEventsHandler {

    /// Rows are deleted before send (existing at-most-once policy); finish only the captured restore.
    private func didSend(_ operation: RestoreOperation, success: Bool) {
        guard isCurrent(operation) else { return }
        if success {
            logger.info("✅ Offline batch events sent successfully")
        } else {
            logger.error("⚠️ Offline batch events send failed or timed out")
        }
        finishRestore(operation)
    }
}
