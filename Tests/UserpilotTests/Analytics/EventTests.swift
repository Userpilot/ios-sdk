//
//  EventTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class EventTests: XCTestCase {

    func testEventTypeProperties_forEvent() {
        let eventType = EventType.event("Button Clicked")

        XCTAssertEqual(eventType.eventName, "track")
        XCTAssertTrue(eventType.isEvent)
        XCTAssertFalse(eventType.isAutoCaptureEvent)
        XCTAssertTrue(eventType.isTrackEvent)
        XCTAssertFalse(eventType.isScreenEvent)
        XCTAssertFalse(eventType.isIdentifyEvent)
        XCTAssertEqual(eventType.eventTitle, "Button Clicked")
        XCTAssertNil(eventType.userId)
        XCTAssertNil(eventType.screenTitle)
    }

    func testEventTypeProperties_forScreen() {
        let eventType = EventType.screen("Home Screen")

        XCTAssertEqual(eventType.eventName, "screen")
        XCTAssertTrue(eventType.isScreenEvent)
        XCTAssertFalse(eventType.isEvent)
        XCTAssertFalse(eventType.isAutoCaptureEvent)
        XCTAssertFalse(eventType.isTrackEvent)
        XCTAssertFalse(eventType.isIdentifyEvent)
        XCTAssertEqual(eventType.screenTitle, "Home Screen")
        XCTAssertNil(eventType.eventTitle)
        XCTAssertNil(eventType.userId)
    }

    func testEventTypeProperties_forIdentify() {
        let eventType = EventType.identify("user-00000")

        XCTAssertEqual(eventType.eventName, "user_identify")
        XCTAssertTrue(eventType.isIdentifyEvent)
        XCTAssertFalse(eventType.isEvent)
        XCTAssertFalse(eventType.isAutoCaptureEvent)
        XCTAssertFalse(eventType.isTrackEvent)
        XCTAssertFalse(eventType.isScreenEvent)
        XCTAssertEqual(eventType.userId, "user-00000")
        XCTAssertNil(eventType.eventTitle)
        XCTAssertNil(eventType.screenTitle)
    }

    func testEventDerivedProperties() {
        let event = Event(type: .event("Clicked CTA"))

        XCTAssertEqual(event.eventName, "track")
        XCTAssertEqual(event.eventTitle, "Clicked CTA")
        XCTAssertTrue(event.isTrackEvent)
        XCTAssertFalse(event.isIdentifyEvent)
        XCTAssertNil(event.userId)
        XCTAssertNil(event.screenTitle)
        XCTAssertEqual(event.userpilotAnalytic, .event)
    }

    func testAutoCaptureEventTypeProperties() {
        let eventType = EventType.autoCaptureEvent
        let event = Event(
            type: eventType,
            properties: ["target": "button"],
            interactionEventName: InteractionEventType.tap.rawValue
        )

        XCTAssertEqual(eventType.eventName, "mobile_autocapture")
        XCTAssertFalse(eventType.isEvent)
        XCTAssertTrue(eventType.isAutoCaptureEvent)
        XCTAssertTrue(eventType.isTrackEvent)
        XCTAssertFalse(eventType.isScreenEvent)
        XCTAssertFalse(eventType.isIdentifyEvent)
        XCTAssertNil(eventType.eventTitle)
        XCTAssertNil(eventType.userId)
        XCTAssertNil(eventType.screenTitle)
        XCTAssertEqual(event.eventName, "mobile_autocapture")
        XCTAssertTrue(event.isTrackEvent)
        XCTAssertEqual(event.userpilotAnalytic, .event)
        XCTAssertEqual(event.interactionEventName, "tap")
        XCTAssertEqual(event.properties?["target"] as? String, "button")
    }

    func testEventDerivedAnalyticsTypeForScreenAndIdentify() {
        let screen = Event(type: .screen("Home"))
        let identify = Event(type: .identify("user-1"))

        XCTAssertEqual(screen.userpilotAnalytic, .screen)
        XCTAssertEqual(screen.screenTitle, "Home")
        XCTAssertEqual(screen.eventTitle, "")
        XCTAssertEqual(identify.userpilotAnalytic, .identify)
        XCTAssertEqual(identify.userId, "user-1")
        XCTAssertEqual(identify.eventTitle, "")
    }

    func testEventToUser() {
        let props: Payload = ["age": 25]
        let company: Payload = ["name": "Acme Inc."]
        let event = Event(type: .identify("user-abc"), properties: props, company: company)

        let user = event.toUser()

        XCTAssertEqual(user.userId, "user-abc")
        XCTAssertEqual(user.properties["age"] as? Int, 25)
        XCTAssertEqual(user.company["name"] as? String, "Acme Inc.")
    }

}
