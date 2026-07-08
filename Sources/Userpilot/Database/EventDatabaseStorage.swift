//
//  EventSQLiteStorage.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  EventSQLiteStorage manages the SQLite database for storing events locally when
//  the app is offline or socket is disconnected. It handles size limits, record counts,
//  and provides thread-safe operations for event persistence.
//

// swiftlint:disable file_length

import Foundation
import SQLite3

// MARK: - EventStoring Protocol

internal protocol EventStoring: AnyObject {
    /// Saves an event to storage if limits are not exceeded
    /// - Parameters:
    ///   - activity: The event to save
    ///   - completion: Completion handler called with true if saved successfully, false if limits were exceeded
    func saveEvent(_ activity: EventStorage, completion: @escaping (Bool) -> Void)

    /// Retrieves all events from storage and deletes them atomically
    /// - Parameter completion: Completion handler called with the list of all stored events
    func getAllEventsAndDelete(completion: @escaping ([EventStorage]) -> Void)

    /// Deletes a single event from storage
    /// - Parameter activity: The event to delete
    func deleteEvent(_ activity: EventStorage)

    /// Deletes all events from storage
    func deleteAllEvents()

    /// Gets current storage statistics
    /// - Returns: Storage stats including count, size, and limits
    func getStorageStats() -> DatabaseStats

    /// Fast check to determine if there are any events in storage
    /// - Returns: true if there are stored events, false otherwise
    func hasEvents() -> Bool
}

// MARK: - EventSQLiteStorage

// swiftlint:disable:next type_body_length
internal class EventDatabaseStorage: EventStoring {

    // MARK: - Properties

    private let database: OpaquePointer?
    private let databaseURL: URL
    private let queue = DispatchQueue(
        label: Constants.DispatchQueues.database,
        qos: .userInitiated
    )
    private let decoder = JSONDecoder()

    /// Logger used for internal logging of operations and errors.
    private let logger: Logging

    // MARK: - Initialization

    init(container: DIContainer) {
        let config = container.resolve(Userpilot.Config.self)
        self.logger = config.logger

        // Application Support, not Documents: Documents is user-visible (Files app)
        // and semantically for user-created content. The events DB is SDK-internal.
        let userpilotRoot = FileManager.default.applicationSupportDirectory
            .appendingPathComponent("userpilot", isDirectory: true)
        let dbURL = userpilotRoot
            .appendingPathComponent("events/\(config.token)/events.sqlite")
        self.databaseURL = dbURL

        // Create directory with a protection class that still allows background
        // writes after reboot, before first unlock.
        do {
            try FileManager.default.createDirectory(
                at: dbURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                ]
            )
        } catch {
            logger.error(
                "❗ Failed to create event storage directory: %{public}@", error.localizedDescription
            )
        }

        // Analytics events must never enter iCloud/iTunes backups.
        EventDatabaseStorage.excludeFromBackup(userpilotRoot, logger: logger)

        // Remove the legacy DB that older builds kept in Documents. Events are
        // ephemeral analytics; deleting beats migrating backed-up data forward.
        EventDatabaseStorage.deleteLegacyDocumentsDatabase(logger: logger)

        var dbPointer: OpaquePointer?
        guard sqlite3_open(dbURL.path, &dbPointer) == SQLITE_OK else {
            logger.error("❗ Unable to open event storage database")
            self.database = nil
            return
        }
        self.database = dbPointer

        // Must run BEFORE the CREATE below so a dropped table is recreated in
        // the same launch.
        dropTableOnSchemaChange()

        // Create table with size tracking
        let createTableQuery = """
            CREATE TABLE IF NOT EXISTS Events(
                requestId TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                created_at INTEGER DEFAULT (strftime('%s','now')),
                size_bytes INTEGER DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_created_at ON Events(created_at);
            """

        var errorMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, createTableQuery, nil, nil, &errorMsg) != SQLITE_OK {
            let error = String(cString: errorMsg!)
            sqlite3_free(errorMsg)
            logger.error("❗ Failed to create event storage table: %{public}@", error)

        }

    }

    // MARK: - Schema Versioning (drop-on-change, no migrations)

    /**
     * Compares the stored `PRAGMA user_version` with `Constants.Database.schemaVersion`.
     * No-migration policy: offline events are ephemeral analytics, so on ANY version
     * mismatch the Events table is dropped and recreated instead of migrated. Bump
     * the constant whenever the Events schema changes.
     */
    private func dropTableOnSchemaChange() {
        guard let database else { return }

        var stmt: OpaquePointer?
        var currentVersion: Int32 = 0
        if sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK,
            sqlite3_step(stmt) == SQLITE_ROW {
            currentVersion = sqlite3_column_int(stmt, 0)
        }
        sqlite3_finalize(stmt)

        guard currentVersion != Constants.Database.schemaVersion else { return }

        if currentVersion > 0 {
            logger.info(
                "🗃️ Events schema changed (%d -> %d): dropping table",
                currentVersion, Constants.Database.schemaVersion)
            _ = sqlite3_exec(database, "DROP TABLE IF EXISTS Events;", nil, nil, nil)
        }

        let stampQuery = "PRAGMA user_version = \(Constants.Database.schemaVersion);"
        if sqlite3_exec(database, stampQuery, nil, nil, nil) != SQLITE_OK {
            logger.error("❗ Failed to stamp event storage schema version")
        }
    }

    // MARK: - Storage Location Hardening

    private static func excludeFromBackup(_ url: URL, logger: Logging) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
        } catch {
            logger.error(
                "❗ Failed to exclude event storage from backup: %{public}@",
                error.localizedDescription)
        }
    }

    private static func deleteLegacyDocumentsDatabase(logger: Logging) {
        let legacyRoot = FileManager.default.documentsDirectory
            .appendingPathComponent("userpilot/events", isDirectory: true)
        guard FileManager.default.fileExists(atPath: legacyRoot.path) else { return }
        do {
            try FileManager.default.removeItem(at: legacyRoot)
            logger.info("🗃️ Removed legacy events database from Documents")
        } catch {
            logger.error(
                "❗ Failed to remove legacy events database: %{public}@",
                error.localizedDescription)
        }
    }

    deinit {
        tryCatch {
            _ = queue.sync {
                sqlite3_close(database)
            }
        }
    }

    // MARK: - EventStoring

    /**
     * Saves an event to the database if limits are not exceeded.
     *
     * This method checks current storage limits before saving:
     * - If event count >= MAX_EVENT_COUNT, the event is rejected
     * - If total size >= MAX_SIZE_BYTES, the event is rejected
     * - Otherwise, the event is saved
     *
     * Thread-safety: Uses serial queue to ensure atomic read-check-write operations to prevent race
     * conditions when saving events concurrently.
     *
     * - Parameters:
     *   - activity: The event to save
     *   - completion: Completion handler called with true if saved successfully, false if limits were exceeded
     */
    func saveEvent(_ activity: EventStorage, completion: @escaping (Bool) -> Void) {
        tryCatch {
            queue.async { [weak self] in
                guard let self = self else {
                    completion(false)
                    return
                }
                let result = self.performSaveEvent(activity)
                completion(result)
            }
        }
    }

    /**
     * Retrieves all events from the database and deletes them.
     *
     * This method atomically:
     * 1. Fetches all events from storage
     * 2. Deletes all events from storage
     *
     * - Parameter completion: Completion handler called with the list of all stored events
     */
    func getAllEventsAndDelete(completion: @escaping ([EventStorage]) -> Void) {
        tryCatch {
            queue.async { [weak self] in
                guard let self = self else {
                    completion([])
                    return
                }

                let events = self.performRead()
                if !events.isEmpty {
                    self.performDeleteAll()
                    self.logger.info(
                        "✅ Retrieved and deleted %{public}d events from storage", events.count)
                }
                completion(events)
            }
        }
    }

    /// Deletes a single event from the database.
    /// - Parameter activity: The event to delete
    func deleteEvent(_ activity: EventStorage) {
        tryCatch {
            queue.async { [weak self] in
                guard let self = self else { return }
                self.performDeleteEvent(activity)
            }
        }
    }

    /// Deletes all events from the database.
    func deleteAllEvents() {
        tryCatch {
            queue.async { [weak self] in
                guard let self = self else { return }

                let count = self.performGetRecordCount()
                self.performDeleteAll()
                self.logger.info("✅ Deleted %{public}d events from storage", count)
            }
        }
    }

    /**
     * Gets storage statistics for monitoring purposes.
     *
     * - Returns: Storage statistics including count, size, and limit information
     */
    func getStorageStats() -> DatabaseStats {
        return queue.sync { [weak self] in
            guard let self = self else {
                return DatabaseStats(
                    eventCount: 0,
                    totalSizeBytes: 0,
                    maxEventCount: Constants.Database.maxEventCount,
                    maxSizeBytes: Constants.Database.maxSizeBytes,
                    isCountLimitReached: false,
                    isSizeLimitReached: false
                )
            }

            let count = self.getEventCount()
            let size = self.getTotalSize()

            return DatabaseStats(
                eventCount: count,
                totalSizeBytes: size,
                maxEventCount: Constants.Database.maxEventCount,
                maxSizeBytes: Constants.Database.maxSizeBytes,
                isCountLimitReached: count >= Constants.Database.maxEventCount,
                isSizeLimitReached: size >= Constants.Database.maxSizeBytes
            )
        }
    }

    /**
     * Fast check to determine if there are any events in storage.
     * This is optimized for performance by only checking if count > 0.
     *
     * - Returns: true if there are stored events, false otherwise
     */
    func hasEvents() -> Bool {
        return queue.sync { [weak self] in
            guard let self = self else { return false }
            return self.getEventCount() > 0
        }
    }

    // MARK: - Private Methods

    /*
     * Internal save implementation with limit checking
     */
    // swiftlint:disable:next function_body_length
    private func performSaveEvent(_ activity: EventStorage) -> Bool {
        guard let database else { return false }

        guard let jsonData = tryCatch(code: { try self.encoder.encode(activity) }),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            logger.error("❗ Failed to encode event for storage")
            return false
        }

        let dataSize = jsonString.utf8.count

        // Check current limits
        let currentCount = performGetRecordCount()
        let currentSize = performGetTotalSizeBytes()

        // Check if limits are exceeded
        if currentCount >= Constants.Database.maxEventCount {
            logger.error(
                "⚠️ Event storage limit reached: %{public}d events. Event will not be saved.",
                currentCount
            )
            return false
        }

        if currentSize >= Constants.Database.maxSizeBytes {
            logger.error(
                "⚠️ Event storage size limit reached: %{public}@. Event will not be saved.",
                formatBytes(currentSize)
            )
            return false
        }

        // Check if adding this event would exceed size limit
        let newTotalSize = currentSize + Int64(dataSize)
        if newTotalSize > Constants.Database.maxSizeBytes {
            logger.error(
                "⚠️ Event would exceed storage limit. Current: %{public}@, Event: %{public}@, Limit: %{public}@.",
                formatBytes(currentSize),
                formatBytes(Int64(dataSize)),
                formatBytes(Constants.Database.maxSizeBytes)
            )
            return false
        }

        // Limits not exceeded, save the event
        let requestId = activity.requestId.uuidString

        let query = """
            INSERT OR REPLACE INTO Events (requestId, data, created_at, size_bytes) VALUES (?, ?, ?, ?);
            """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK else {
            logger.error("❗ Failed to prepare save statement")
            return false
        }

        sqlite3_bind_text(stmt, 1, (requestId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (jsonString as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 3, Int64(activity.createdAt))
        sqlite3_bind_int(stmt, 4, Int32(dataSize))

        if sqlite3_step(stmt) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(database))
            logger.error("❗ Event save failed: %{public}@", error)
            return false
        }

        logger.debug(
            "✅ Event saved. Count: %{public}d/%{public}d, Size: %{public}@/%{public}@",
            currentCount + 1,
            Constants.Database.maxEventCount,
            formatBytes(newTotalSize),
            formatBytes(Constants.Database.maxSizeBytes)
        )

        return true
    }

    private func performRead() -> [EventStorage] {
        guard let database else { return [] }

        let query = "SELECT data FROM Events ORDER BY created_at, rowid;"
        var stmt: OpaquePointer?
        var activities: [EventStorage] = []

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK else {
            logger.error("❗ Failed to prepare read statement")
            return []
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0),
                let data = String(cString: cString).data(using: .utf8),
                let activity = tryCatch(code: {
                    try self.decoder.decode(EventStorage.self, from: data)
                }) {
                activities.append(activity)
            }
        }

        return activities
    }

    private func performDeleteEvent(_ activity: EventStorage) {
        guard let database else { return }

        let query = "DELETE FROM Events WHERE requestId = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK else {
            logger.error("❗ Failed to prepare delete statement")
            return
        }

        let requestId = activity.requestId.uuidString
        sqlite3_bind_text(stmt, 1, (requestId as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            logger.debug("✅ Event deleted: %{public}@", requestId)
        } else {
            let error = String(cString: sqlite3_errmsg(database))
            logger.error("❗ Event delete failed: %{public}@", error)
        }
    }

    private func performDeleteAll() {
        guard let database else { return }

        if sqlite3_exec(database, "DELETE FROM Events;", nil, nil, nil) != SQLITE_OK {
            logger.error("❗ Failed to delete all events")
        }

        vacuumDatabase()
    }

    // MARK: - Size Management

    private func performGetRecordCount() -> Int {
        guard let database else { return 0 }

        let query = "SELECT COUNT(*) FROM Events;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK,
            sqlite3_step(stmt) == SQLITE_ROW
        else {
            return 0
        }

        return Int(sqlite3_column_int(stmt, 0))
    }

    private func performGetTotalSizeBytes() -> Int64 {
        guard let database else { return 0 }

        let query = "SELECT COALESCE(SUM(size_bytes), 0) FROM Events;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(database, query, -1, &stmt, nil) == SQLITE_OK,
            sqlite3_step(stmt) == SQLITE_ROW
        else {
            return 0
        }

        return sqlite3_column_int64(stmt, 0)
    }

    /**
     * Gets the current count of events in storage.
     *
     * - Returns: The number of events currently stored
     */
    private func getEventCount() -> Int {
        return tryCatch {
            performGetRecordCount()
        } ?? 0
    }

    /**
     * Gets the current total size of events in storage.
     *
     * - Returns: The total size in bytes of all stored events
     */
    private func getTotalSize() -> Int64 {
        return tryCatch {
            performGetTotalSizeBytes()
        } ?? 0
    }

    private func vacuumDatabase() {
        guard let database else { return }

        let beforeSize = performGetDatabaseSize()

        if sqlite3_exec(database, "VACUUM;", nil, nil, nil) == SQLITE_OK {
            let afterSize = performGetDatabaseSize()
            let reclaimed = beforeSize - afterSize
            logger.debug(
                "🛑 VACUUM completed. Reclaimed: %{public}@",
                formatBytes(reclaimed)
            )
        }
    }

    private func performGetDatabaseSize() -> Int64 {
        return tryCatch {
            let attributes = try FileManager.default.attributesOfItem(atPath: databaseURL.path)
            return attributes[.size] as? Int64 ?? 0
        } ?? 0
    }

    // MARK: - Helper Methods

    private var encoder: JSONEncoder {
        return UserpilotEncoder.shared
    }

    /**
     * Formats bytes to human-readable string.
     *
     * - Parameter bytes: The number of bytes to format
     * - Returns: Formatted string (e.g., "1.5 MB")
     */
    private func formatBytes(_ bytes: Int64) -> String {
        let bytesInKilobyte: Int64 = 1024
        let bytesInMegabyte = bytesInKilobyte * 1024
        let bytesInGigabyte = bytesInMegabyte * 1024

        switch bytes {
        case bytesInGigabyte...:
            return String(format: "%.2f GB", Double(bytes) / Double(bytesInGigabyte))
        case bytesInMegabyte...:
            return String(format: "%.2f MB", Double(bytes) / Double(bytesInMegabyte))
        case bytesInKilobyte...:
            return String(format: "%.2f KB", Double(bytes) / Double(bytesInKilobyte))
        default:
            return "\(bytes) B"
        }
    }
}

// MARK: - FileManager Extension

internal extension FileManager {
    fileprivate var documentsDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    fileprivate var applicationSupportDirectory: URL {
        urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
