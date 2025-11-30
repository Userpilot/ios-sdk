//
//  EventStorageTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
class EventStorageTests: XCTestCase {

    // MARK: - Helper Methods

    private func createEvent(name: String) -> Event {
        return Event(type: .event(name))
    }

    private func createScreenEvent(name: String) -> Event {
        return Event(type: .screen(name))
    }

    private func createIdentifyEvent(userId: String) -> Event {
        return Event(type: .identify(userId))
    }

    // MARK: - Initialization Tests

    func testInit_withValidEvent_createsEventStorage() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertEqual(eventStorage?.token, token)
        XCTAssertEqual(eventStorage?.userId, userId)
        XCTAssertGreaterThan(eventStorage?.sizeBytes ?? 0, 0)
        XCTAssertGreaterThan(eventStorage?.createdAt ?? 0, 0)
    }

    func testInit_withScreenEvent_createsEventStorage() {
        // Arrange
        let event = createScreenEvent(name: "HomeScreen")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertEqual(eventStorage?.token, token)
        XCTAssertEqual(eventStorage?.userId, userId)
    }

    func testInit_withIdentifyEvent_createsEventStorage() {
        // Arrange
        let event = createIdentifyEvent(userId: "user_456")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertEqual(eventStorage?.token, token)
        XCTAssertEqual(eventStorage?.userId, userId)
    }

    func testInit_withEventWithProperties_createsEventStorage() {
        // Arrange
        var event = createEvent(name: "purchase")
        event.properties = ["item": "product_123", "price": 29.99, "quantity": 2]
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertGreaterThan(eventStorage?.sizeBytes ?? 0, 0)
    }

    func testInit_withEventWithCompany_createsEventStorage() {
        // Arrange
        var event = createIdentifyEvent(userId: "user_123")
        event.company = ["id": "company_456", "name": "Test Company"]
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertGreaterThan(eventStorage?.sizeBytes ?? 0, 0)
    }

    // MARK: - RequestId Tests

    func testInit_generatesUniqueRequestIds() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage1 = EventStorage(event, token, userId)
        let eventStorage2 = EventStorage(event, token, userId)
        let eventStorage3 = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage1)
        XCTAssertNotNil(eventStorage2)
        XCTAssertNotNil(eventStorage3)
        XCTAssertNotEqual(eventStorage1?.requestId, eventStorage2?.requestId)
        XCTAssertNotEqual(eventStorage2?.requestId, eventStorage3?.requestId)
        XCTAssertNotEqual(eventStorage1?.requestId, eventStorage3?.requestId)
    }

    // MARK: - CreatedAt Tests

    func testInit_setsCreatedAtInMilliseconds() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"
        let beforeTimestamp = Date().timeIntervalSince1970 * 1_000.0

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        let createdAt = eventStorage?.createdAt ?? 0
        let afterTimestamp = Date().timeIntervalSince1970 * 1_000.0

        XCTAssertGreaterThanOrEqual(createdAt, beforeTimestamp)
        XCTAssertLessThanOrEqual(createdAt, afterTimestamp)
    }

    func testInit_multipleCreations_haveIncreasingTimestamps() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage1 = EventStorage(event, token, userId)
        Thread.sleep(forTimeInterval: 0.001)  // Small delay to ensure different timestamps
        let eventStorage2 = EventStorage(event, token, userId)
        Thread.sleep(forTimeInterval: 0.001)
        let eventStorage3 = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage1)
        XCTAssertNotNil(eventStorage2)
        XCTAssertNotNil(eventStorage3)
        XCTAssertLessThanOrEqual(eventStorage1!.createdAt, eventStorage2!.createdAt)
        XCTAssertLessThanOrEqual(eventStorage2!.createdAt, eventStorage3!.createdAt)
    }

    // MARK: - SizeBytes Tests

    func testInit_calculatesSizeBytes() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertGreaterThan(eventStorage?.sizeBytes ?? 0, 0)
    }

    func testInit_largerEventHasLargerSize() {
        // Arrange
        let simpleEvent = createEvent(name: "simple")
        var complexEvent = createEvent(name: "complex_event_with_long_name")
        complexEvent.properties = [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3",
            "key4": "value4",
            "key5": "value5"
        ]
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let simpleEventStorage = EventStorage(simpleEvent, token, userId)
        let complexEventStorage = EventStorage(complexEvent, token, userId)

        // Assert
        XCTAssertNotNil(simpleEventStorage)
        XCTAssertNotNil(complexEventStorage)
        XCTAssertGreaterThan(complexEventStorage!.sizeBytes, simpleEventStorage!.sizeBytes)
    }

    // MARK: - ToEvent Tests

    func testToEvent_returnsOriginalEvent() {
        // Arrange
        let originalEvent = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"
        let eventStorage = EventStorage(originalEvent, token, userId)

        // Act
        let decodedEvent = eventStorage?.toEvent()

        // Assert
        XCTAssertNotNil(decodedEvent)
        XCTAssertEqual(decodedEvent?.eventTitle, "test_event")
        XCTAssertTrue(decodedEvent?.isTrackEvent ?? false)
    }

    func testToEvent_withScreenEvent_returnsCorrectEvent() {
        // Arrange
        let originalEvent = createScreenEvent(name: "ProfileScreen")
        let token = "NX-12345"
        let userId = "user_123"
        let eventStorage = EventStorage(originalEvent, token, userId)

        // Act
        let decodedEvent = eventStorage?.toEvent()

        // Assert
        XCTAssertNotNil(decodedEvent)
        XCTAssertEqual(decodedEvent?.screenTitle, "ProfileScreen")
        XCTAssertTrue(decodedEvent?.isScreenEvent ?? false)
    }

    func testToEvent_withIdentifyEvent_returnsCorrectEvent() {
        // Arrange
        let originalEvent = createIdentifyEvent(userId: "user_789")
        let token = "NX-12345"
        let userId = "user_123"
        let eventStorage = EventStorage(originalEvent, token, userId)

        // Act
        let decodedEvent = eventStorage?.toEvent()

        // Assert
        XCTAssertNotNil(decodedEvent)
        XCTAssertEqual(decodedEvent?.userId, "user_789")
        XCTAssertTrue(decodedEvent?.isIdentifyEvent ?? false)
    }

    func testToEvent_withProperties_preservesProperties() {
        // Arrange
        var originalEvent = createEvent(name: "purchase")
        originalEvent.properties = ["item_id": "SKU-123", "price": 49.99]
        let token = "NX-12345"
        let userId = "user_123"
        let eventStorage = EventStorage(originalEvent, token, userId)

        // Act
        let decodedEvent = eventStorage?.toEvent()

        // Assert
        XCTAssertNotNil(decodedEvent)
        XCTAssertEqual(decodedEvent?.eventTitle, "purchase")
        XCTAssertNotNil(decodedEvent?.properties)
        XCTAssertEqual(decodedEvent?.properties?["item_id"] as? String, "SKU-123")
    }

    func testToEvent_withCompany_preservesCompany() {
        // Arrange
        var originalEvent = createIdentifyEvent(userId: "user_123")
        originalEvent.company = ["company_id": "COMP-456", "name": "Acme Corp"]
        let token = "NX-12345"
        let userId = "user_123"
        let eventStorage = EventStorage(originalEvent, token, userId)

        // Act
        let decodedEvent = eventStorage?.toEvent()

        // Assert
        XCTAssertNotNil(decodedEvent)
        XCTAssertNotNil(decodedEvent?.company)
        XCTAssertEqual(decodedEvent?.company?["company_id"] as? String, "COMP-456")
        XCTAssertEqual(decodedEvent?.company?["name"] as? String, "Acme Corp")
    }

    // MARK: - Codable Tests

    func testCodable_encodesAndDecodesCorrectly() throws {
        // Arrange
        let originalEvent = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = "user_123"
        guard let eventStorage = EventStorage(originalEvent, token, userId) else {
            XCTFail("Failed to create EventStorage")
            return
        }

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(eventStorage)

        // Act - Decode
        let decoder = JSONDecoder()
        let decodedEventStorage = try decoder.decode(EventStorage.self, from: data)

        // Assert
        XCTAssertEqual(decodedEventStorage.requestId, eventStorage.requestId)
        XCTAssertEqual(decodedEventStorage.token, eventStorage.token)
        XCTAssertEqual(decodedEventStorage.userId, eventStorage.userId)
        XCTAssertEqual(decodedEventStorage.createdAt, eventStorage.createdAt)
        XCTAssertEqual(decodedEventStorage.sizeBytes, eventStorage.sizeBytes)
        XCTAssertEqual(decodedEventStorage.data, eventStorage.data)
    }

    func testCodable_withComplexEvent_encodesAndDecodesCorrectly() throws {
        // Arrange
        var originalEvent = createEvent(name: "complex_event")
        originalEvent.properties = ["key1": "value1", "key2": 123]
        originalEvent.company = ["id": "comp_1"]
        let token = "NX-12345"
        let userId = "user_123"
        guard let eventStorage = EventStorage(originalEvent, token, userId) else {
            XCTFail("Failed to create EventStorage")
            return
        }

        // Act - Encode and Decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(eventStorage)
        let decoder = JSONDecoder()
        let decodedEventStorage = try decoder.decode(EventStorage.self, from: data)

        // Assert
        XCTAssertEqual(decodedEventStorage.requestId, eventStorage.requestId)
        XCTAssertEqual(decodedEventStorage.token, eventStorage.token)
        XCTAssertEqual(decodedEventStorage.userId, eventStorage.userId)

        // Verify the event can be decoded
        let decodedEvent = decodedEventStorage.toEvent()
        XCTAssertNotNil(decodedEvent)
        XCTAssertEqual(decodedEvent?.eventTitle, "complex_event")
    }

    // MARK: - Edge Cases

    func testInit_withEmptyEventName_createsEventStorage() {
        // Arrange
        let event = createEvent(name: "")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
    }

    func testInit_withLongEventName_createsEventStorage() {
        // Arrange
        let longName = String(repeating: "a", count: 1000)
        let event = createEvent(name: longName)
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertGreaterThan(eventStorage?.sizeBytes ?? 0, 1000)
    }

    func testInit_withEmptyToken_createsEventStorage() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = ""
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertEqual(eventStorage?.token, "")
    }

    func testInit_withEmptyUserId_createsEventStorage() {
        // Arrange
        let event = createEvent(name: "test_event")
        let token = "NX-12345"
        let userId = ""

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
        XCTAssertEqual(eventStorage?.userId, "")
    }

    func testInit_withSpecialCharacters_createsEventStorage() {
        // Arrange
        let event = createEvent(name: "test!@#$%^&*()_+-=[]{}|;':,.<>?/~`")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)
    }

    func testInit_withUnicodeCharacters_createsEventStorage() {
        // Arrange
        let event = createEvent(name: "测试事件 🎉 مرحبا")
        let token = "NX-12345"
        let userId = "user_123"

        // Act
        let eventStorage = EventStorage(event, token, userId)

        // Assert
        XCTAssertNotNil(eventStorage)

        let decodedEvent = eventStorage?.toEvent()
        XCTAssertEqual(decodedEvent?.eventTitle, "测试事件 🎉 مرحبا")
    }
}
// swiftlint:enable all
