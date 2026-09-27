import XCTest
@testable import Userpilot

// swiftlint:disable all

class StoredOfflineEventTests: XCTestCase {

    private func encodeDecode(_ stored: StoredOfflineEvent) throws -> StoredOfflineEvent {
        let data = try UserpilotEncoder.shared.encode(stored)
        return try UserpilotDecoder.shared.decode(StoredOfflineEvent.self, from: data)
    }

    func testInternalEnvelope_roundTrips_preservingIntegerPayloadValues() throws {
        let sdkEvent = MockSDKEvent(
            eventName: "seen_mobile_content_step",
            eventPayload: ["mobile_content_id": 42, "step_id": 7]
        )

        let restored = try encodeDecode(StoredOfflineEvent(sdkEvent: sdkEvent))

        XCTAssertTrue(restored.isInternalEvent)
        XCTAssertEqual(restored.eventType, "seen_mobile_content_step")
        // AnyCodable decodes Int before Double, so ids do not become 42.0 on the wire.
        XCTAssertEqual(restored.payload?["mobile_content_id"] as? Int, 42)
        XCTAssertEqual(restored.payload?["step_id"] as? Int, 7)
    }

    func testInternalEnvelope_preservesMixedPrimitiveTypes() throws {
        let sdkEvent = MockSDKEvent(
            eventName: "NPS_feedback",
            eventPayload: [
                "score": 9,
                "survey_question_key": "q1",
                "feedback": "great",
                "rating": 4.5,
                "skipped": false
            ]
        )

        let restored = try encodeDecode(StoredOfflineEvent(sdkEvent: sdkEvent))

        XCTAssertEqual(restored.payload?["score"] as? Int, 9)
        XCTAssertEqual(restored.payload?["survey_question_key"] as? String, "q1")
        XCTAssertEqual(restored.payload?["rating"] as? Double, 4.5)
        XCTAssertEqual(restored.payload?["skipped"] as? Bool, false)
    }

    func testAnalyticsEnvelope_roundTripsTheNestedEvent() throws {
        let event = Event(type: .screen("Home"))

        let restored = try encodeDecode(StoredOfflineEvent(event: event))

        XCTAssertFalse(restored.isInternalEvent)
        XCTAssertEqual(restored.event?.screenTitle, "Home")
    }

    func testEventStorage_roundTripsAnAnalyticsEventThroughTheEnvelope() throws {
        let event = Event(type: .event("purchase"))
        let storage = try XCTUnwrap(EventStorage(event, "NX-00000", "user-1"))

        let stored = try XCTUnwrap(storage.toStoredEvent())

        XCTAssertFalse(stored.isInternalEvent)
        XCTAssertEqual(stored.event?.eventTitle, "purchase")
        XCTAssertGreaterThan(storage.sizeBytes, 0)
    }
}

// swiftlint:enable all
