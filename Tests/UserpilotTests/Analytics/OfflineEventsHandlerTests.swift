//
//  OfflineEventsHandlerTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

class OfflineEventsHandlerTests: XCTestCase {

    var handler: OfflineEventsHandler!
    var userpilot: MockUserpilot!
    var eventStore: MockEventStorage!
    var storage: MockStorage!
    var socketManager: MockSocketManager!
    var logger: MockLogger!

    override func setUpWithError() throws {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        logger = MockLogger()
        config.logger = logger
        userpilot = MockUserpilot(config: config)
        eventStore = try XCTUnwrap(userpilot.container.resolve(EventStoring.self) as? MockEventStorage)
        storage = try XCTUnwrap(userpilot.container.resolve(DataStoring.self) as? MockStorage)
        socketManager = try XCTUnwrap(
            userpilot.container.resolve(SocketManaging.self) as? MockSocketManager)
        storage.userId = "user-1"
        handler = OfflineEventsHandler(container: userpilot.container)
    }

    override func tearDown() {
        socketManager?.onPublish = nil
        handler = nil
        eventStore = nil
        storage = nil
        socketManager = nil
        logger = nil
        userpilot = nil
        super.tearDown()
    }

    func testSaveSDKEvent_persistsAnInternalRow() throws {
        let sdkEvent = MockSDKEvent(
            eventName: "seen_mobile_content_step",
            eventPayload: ["mobile_content_id": 42, "step_id": 7]
        )

        handler.saveSDKEventToLocalStorage(sdkEvent)

        XCTAssertEqual(eventStore.events.count, 1)
        let stored = try XCTUnwrap(eventStore.events.first?.toStoredEvent())
        XCTAssertTrue(stored.isInternalEvent)
        XCTAssertEqual(stored.kind, .internalEvent)
        XCTAssertEqual(stored.eventType, "seen_mobile_content_step")
        XCTAssertNil(stored.event)
        XCTAssertEqual(stored.payload?["mobile_content_id"] as? Int, 42)
        XCTAssertEqual(stored.payload?["step_id"] as? Int, 7)
        XCTAssertEqual(eventStore.events.first?.userId, "user-1")
        XCTAssertEqual(eventStore.events.first?.token, "NX-00000")
    }

    func testSaveSDKEvent_dropsTheEventWhenThereIsNoUserId() {
        // Prove the identical call DOES write while `storage.userId` is set, so the
        // empty assertion below is attributable to the guard rather than to a call
        // that would never have written anything.
        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))
        XCTAssertEqual(eventStore.events.count, 1)
        eventStore.events.removeAll()

        storage.userId = ""

        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))

        XCTAssertTrue(eventStore.events.isEmpty)
        // The guard returns before touching the store at all — not by deleting rows.
        XCTAssertFalse(eventStore.didDeleteAllEvents)
    }

    func testSaveSDKEvent_persistsAlongsideAnalyticsRows() throws {
        handler.saveEventToLocalStorage(event: Event(type: .event("Purchase")))
        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))

        XCTAssertEqual(eventStore.events.count, 2)
        let analytics = try XCTUnwrap(eventStore.events.first?.toStoredEvent())
        let internalRow = try XCTUnwrap(eventStore.events.last?.toStoredEvent())
        XCTAssertFalse(analytics.isInternalEvent)
        XCTAssertTrue(internalRow.isInternalEvent)
    }

    func testClearLocalEvents_removesInternalRowsToo() {
        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))
        XCTAssertEqual(eventStore.events.count, 1)

        handler.clearLocalEvents()

        XCTAssertTrue(eventStore.events.isEmpty)
        XCTAssertTrue(eventStore.didDeleteAllEvents)
    }

    // MARK: - Shared Persist Tail

    func testSave_logsADistinctSuccessMessagePerPath() {
        handler.saveEventToLocalStorage(event: Event(type: .event("Purchase")))
        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))

        XCTAssertEqual(eventStore.events.count, 2)
        // Both paths share one persist-and-log helper; the analytics and internal wording must
        // stay distinguishable through it rather than collapsing into one generic line.
        XCTAssertTrue(logger.loggedInfos.contains { $0.hasPrefix("🗃️ Event saved to local storage:") })
        XCTAssertTrue(
            logger.loggedInfos.contains { $0.hasPrefix("🗃️ Internal event saved to local storage:") })
    }

    func testSave_logsTheLimitExceededMessagePerPathWhenTheStoreRefusesTheRow() {
        eventStore.saveEventResult = false

        handler.saveEventToLocalStorage(event: Event(type: .event("Purchase")))
        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))

        XCTAssertTrue(eventStore.events.isEmpty)
        XCTAssertTrue(logger.loggedErrors.contains("⚠️ Event not saved - storage limit exceeded"))
        XCTAssertTrue(
            logger.loggedErrors.contains("⚠️ Internal event not saved - storage limit exceeded"))
        // Neither path may claim success while the store is refusing rows.
        XCTAssertFalse(logger.loggedInfos.contains { $0.contains("saved to local storage") })
    }

    // MARK: - Restore Helpers

    /// Runs a restore and returns the items of the `batch_events` payload it publishes.
    ///
    /// `MockSocketManager` records nothing of its own — it only forwards to its `onPublish`
    /// closure — so the batch is captured through that closure, which doubles as the fulfilment
    /// signal and lets the test proceed the instant the work is done. The timeout is only a
    /// failure bound. The handler's own completion is unusable here: once a batch is published
    /// the completion is parked in `offlineRestoreCompletion` until the socket ACKs, and the
    /// mock never ACKs.
    private func captureRestoredBatch(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [[String: Any]] {
        let published = expectation(description: "batch_events published")
        var captured: [String: Any]?
        socketManager.onPublish = { eventName, payload in
            guard eventName == Constants.Event.batchEventsEvent else { return }
            captured = payload
            published.fulfill()
        }

        handler.restoreEventsFromLocalStorage { }
        wait(for: [published], timeout: 2.0)

        let batch = try XCTUnwrap(captured, file: file, line: line)
        return try XCTUnwrap(
            batch[Constants.OfflineEvents.eventsProperty] as? [[String: Any]], file: file, line: line)
    }

    /// Runs a restore and returns every socket event name published while it ran.
    ///
    /// Synchronises on the restore completion rather than on `onPublish`, because a test that
    /// expects NO publish gets no `onPublish` callback to wait on. Reaching the completion is
    /// itself evidence: the handler only calls it inline when it decided not to publish, so if a
    /// batch had gone out this would time out rather than pass.
    private func publishedEventNamesDuringRestore() -> [String] {
        var publishedEventNames: [String] = []
        socketManager.onPublish = { eventName, _ in publishedEventNames.append(eventName) }

        let finished = expectation(description: "restore finished")
        handler.restoreEventsFromLocalStorage { finished.fulfill() }
        wait(for: [finished], timeout: 2.0)

        return publishedEventNames
    }

    /// Builds a stored row straight from a raw envelope body, so a test can inject JSON the
    /// production encoder can never emit — an unknown `kind`, or an analytics row carrying no
    /// nested `event`. `EventStorage` has no memberwise initializer (both of its initializers
    /// encode a valid envelope), so the row is built through its own `Codable` conformance rather
    /// than by widening the production API for tests.
    private func makeStoredRow(rawEnvelope: String) throws -> EventStorage {
        let body = Data(rawEnvelope.utf8)
        let row: [String: Any] = [
            "requestId": UUID().uuidString,
            "token": "NX-00000",
            "userId": "user-1",
            "data": body.base64EncodedString(),
            "createdAt": 1_000,
            "sizeBytes": body.count
        ]
        return try UserpilotDecoder.shared.decode(
            EventStorage.self, from: JSONSerialization.data(withJSONObject: row))
    }

    /// An analytics-kind row with no nested `event`: it decodes cleanly, so it is not a decode
    /// failure — it is a row this SDK version has no way to replay.
    private static let unsupportedEnvelope =
        #"{"schema_version":1,"kind":"analytics","event_type":"whatever"}"#

    // MARK: - Internal Event Replay

    func testRestore_spreadsTheInternalPayloadAtTheTopLevelOfTheBatchItem() throws {
        handler.saveSDKEventToLocalStorage(
            MockSDKEvent(
                eventName: "seen_mobile_content_step",
                eventPayload: ["mobile_content_id": 42, "step_id": 7]
            )
        )

        let events = try captureRestoredBatch()

        XCTAssertEqual(events.count, 1)
        let item = try XCTUnwrap(events.first)
        XCTAssertEqual(
            item[Constants.OfflineEvents.eventTypeProperty] as? String,
            "seen_mobile_content_step")

        // Same ISO-8601-with-timezone format the analytics items use.
        let createdAt = try XCTUnwrap(item[Constants.OfflineEvents.createdAtProperty] as? String)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertNotNil(formatter.date(from: createdAt))

        // Spread flat, NOT nested under `metadata` the way an analytics item is. This is the
        // cross-platform wire contract — Android's `buildInternalEventData` emits the same keys.
        XCTAssertEqual(item["mobile_content_id"] as? Int, 42)
        XCTAssertEqual(item["step_id"] as? Int, 7)
        XCTAssertNil(item[Constants.Analytics.metaDataProperty])
        XCTAssertEqual(
            Set(item.keys),
            Set(["event_type", "created_at", "mobile_content_id", "step_id"]))
    }

    func testRestore_preservesTheOrderTheStoreReturnsForMixedRows() throws {
        handler.saveEventToLocalStorage(
            event: Event(type: .screen("Home")), clearStoredEventsFirst: false)
        handler.saveSDKEventToLocalStorage(
            MockSDKEvent(
                eventName: "dismissed_mobile_content", eventPayload: ["mobile_content_id": 42]))
        handler.saveEventToLocalStorage(
            event: Event(type: .event("purchase")), clearStoredEventsFirst: false)

        let events = try captureRestoredBatch()

        // The store hands rows back in insertion (createdAt) order; the handler must preserve
        // that order rather than sort or group by kind.
        XCTAssertEqual(
            events.compactMap { $0[Constants.OfflineEvents.eventTypeProperty] as? String },
            ["screen", "dismissed_mobile_content", "track"]
        )
        // The internal item stays flat while the analytics items keep their nested metadata.
        let eventType = Constants.OfflineEvents.eventTypeProperty
        let internalItem = events.first { $0[eventType] as? String == "dismissed_mobile_content" }
        XCTAssertEqual(internalItem?["mobile_content_id"] as? Int, 42)
        XCTAssertNil(internalItem?[Constants.Analytics.metaDataProperty])
        let analyticsItems = events.filter { $0[eventType] as? String != "dismissed_mobile_content" }
        XCTAssertEqual(analyticsItems.count, 2)
        XCTAssertTrue(analyticsItems.allSatisfy { $0[Constants.Analytics.metaDataProperty] != nil })
    }

    func testRestore_dropsAnUnsupportedRowAndStillPublishesTheRest() throws {
        handler.saveSDKEventToLocalStorage(MockSDKEvent(eventName: "seen_survey"))
        eventStore.events.append(
            try makeStoredRow(rawEnvelope: Self.unsupportedEnvelope))
        XCTAssertEqual(eventStore.events.count, 2)

        let events = try captureRestoredBatch()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            events.first?[Constants.OfflineEvents.eventTypeProperty] as? String, "seen_survey")
        // An unsupported row must not be reported as a decode failure.
        XCTAssertTrue(logger.loggedErrors.contains { $0.contains("Dropping unsupported offline event") })
        XCTAssertFalse(
            logger.loggedErrors.contains { $0.contains("Failed to decode event from local storage") })
    }

    func testRestore_publishesNothingWhenEveryRowIsUnsupported() throws {
        eventStore.events = [try makeStoredRow(rawEnvelope: Self.unsupportedEnvelope)]

        let publishedEventNames = publishedEventNamesDuringRestore()

        XCTAssertTrue(publishedEventNames.isEmpty)
        // Non-vacuity: the row genuinely went through the loop rather than the restore
        // short-circuiting on an empty store. It was read and deleted, the handler logged that it
        // was restoring one row, and it took the unsupported branch.
        XCTAssertTrue(eventStore.events.isEmpty)
        XCTAssertTrue(logger.loggedInfos.contains { $0.contains("Restoring") })
        XCTAssertTrue(logger.loggedErrors.contains { $0.contains("Dropping unsupported offline event") })
    }

    func testRestore_logsADecodeFailureRatherThanUnsupportedForUndecodableRowData() throws {
        // `martian` is not a `StoredOfflineEventKind`, so the envelope itself fails to decode.
        eventStore.events = [
            try makeStoredRow(
                rawEnvelope: #"{"schema_version":1,"kind":"martian","event_type":"whatever"}"#)
        ]

        let publishedEventNames = publishedEventNamesDuringRestore()

        XCTAssertTrue(publishedEventNames.isEmpty)
        XCTAssertTrue(eventStore.events.isEmpty)
        XCTAssertTrue(logger.loggedInfos.contains { $0.contains("Restoring") })
        XCTAssertTrue(
            logger.loggedErrors.contains { $0.contains("Failed to decode event from local storage") })
        XCTAssertFalse(logger.loggedErrors.contains { $0.contains("Dropping unsupported offline event") })
    }
}

// swiftlint:enable all
