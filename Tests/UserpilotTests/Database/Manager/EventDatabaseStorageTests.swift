//
//  EventDatabaseStorageTests.swift
//  Userpilot SDK
//

import SQLite3
import XCTest
@testable import Userpilot

final class EventDatabaseStorageTests: XCTestCase {

    private let token = "NX-\(UUID().uuidString)"
    private var userpilot: MockUserpilot!
    private var sut: EventDatabaseStorage!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: token))
        sut = EventDatabaseStorage(container: userpilot.container)
    }

    override func tearDown() {
        sut = nil
        userpilot = nil
        EventDatabaseTestFiles.removeDatabase(for: token)
        super.tearDown()
    }

    func testHasEvents_returnsInsideRestoreCompletion() {
        let restored = expectation(description: "restore completion")

        sut.getAllEventsAndDelete { [sut] _ in
            XCTAssertEqual(sut?.hasEvents(), false)
            restored.fulfill()
        }

        wait(for: [restored], timeout: 2)
    }

    func testGetAllEventsAndDelete_dropsUndecodableRows() {
        insertUndecodableRow()
        XCTAssertTrue(sut.hasEvents())

        let restored = expectation(description: "restore completion")
        sut.getAllEventsAndDelete { events in
            XCTAssertTrue(events.isEmpty)
            restored.fulfill()
        }
        wait(for: [restored], timeout: 2)

        XCTAssertFalse(sut.hasEvents())
    }

    private func insertUndecodableRow() {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }

        let path = EventDatabaseTestFiles.databaseURL(for: token).path
        XCTAssertEqual(sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)

        let insert = """
            INSERT INTO Events (requestId, data, created_at, size_bytes)
            VALUES ('undecodable', 'not json', 0, 8);
            """
        XCTAssertEqual(sqlite3_exec(database, insert, nil, nil, nil), SQLITE_OK)
    }
}

/// Mirrors the on-disk location `EventDatabaseStorage` derives from the config token.
enum EventDatabaseTestFiles {
    static func databaseURL(for token: String) -> URL {
        directory(for: token).appendingPathComponent("events.sqlite")
    }

    static func removeDatabase(for token: String) {
        try? FileManager.default.removeItem(at: directory(for: token))
    }

    private static func directory(for token: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("userpilot/events/\(token)", isDirectory: true)
    }
}
