//
//  DebugEventMapperTests.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugEventMapperTests: XCTestCase {

    private var mapper: DebugEventMapper!

    override func setUp() {
        super.setUp()
        mapper = DebugEventMapper(clock: { 1_700_000_000_000 })
    }

    func testCustomTrack_mapsToManualChannelWithEventTitle() {
        let event = Event(
            type: .event("Button Clicked"),
            properties: ["plan": "pro"]
        )

        let debugEvent = mapper.fromAnalytics(event)

        XCTAssertEqual(debugEvent.channel, .manual)
        XCTAssertEqual(debugEvent.title, "Button Clicked")
        XCTAssertEqual(debugEvent.typeLabel, "track")
        XCTAssertEqual(debugEvent.timestampMs, 1_700_000_000_000)
        XCTAssertEqual(debugEvent.properties.count, 1)
        XCTAssertEqual(debugEvent.properties[0].key, "plan")
        XCTAssertEqual(debugEvent.properties[0].value, "pro")
    }

    func testIdentify_mapsToManualChannelUsingUserIdAsTitle() {
        let event = Event(
            type: .identify("user-1"),
            properties: ["email": "a@b.c"],
            company: ["name": "Acme"]
        )

        let debugEvent = mapper.fromAnalytics(event)

        XCTAssertEqual(debugEvent.channel, .manual)
        XCTAssertEqual(debugEvent.title, "user-1")
        XCTAssertEqual(debugEvent.typeLabel, "identify")
        XCTAssertTrue(debugEvent.properties.map(\.key).contains("company"))
    }

    func testManualScreen_mapsToManualChannel() {
        let event = Event(
            type: .screen("Home"),
            properties: [AutoCaptureConstants.source: AutoCaptureConstants.manualCaptureSourceValue]
        )

        XCTAssertEqual(mapper.channelFor(event), .manual)
        XCTAssertEqual(mapper.fromAnalytics(event).title, "Home")
        XCTAssertEqual(mapper.fromAnalytics(event).typeLabel, "screen")
    }

    func testAutoCapturedScreen_mapsToAutoCaptureChannel() {
        let event = Event(
            type: .screen("Settings"),
            properties: [AutoCaptureConstants.source: AutoCaptureConstants.autoCaptureSourceValue]
        )

        XCTAssertEqual(mapper.channelFor(event), .autoCapture)
    }

    func testAutoCaptureInteraction_mapsToAutoCaptureChannel() {
        let event = Event(
            type: .autoCaptureEvent,
            properties: [AutoCaptureConstants.targetAction: "click"],
            interactionEventName: "button_click"
        )

        let debugEvent = mapper.fromAnalytics(event)

        XCTAssertEqual(debugEvent.channel, .autoCapture)
        XCTAssertEqual(debugEvent.title, "button_click")
        XCTAssertEqual(debugEvent.typeLabel, "auto_capture")
    }

    func testInternalSDKEvent_mapsToInternalChannel() {
        let sdkEvent = ExperienceFlowSeenEvent(flowId: 42)

        let debugEvent = mapper.fromInternal(sdkEvent)

        XCTAssertEqual(debugEvent.channel, .internalSDK)
        XCTAssertEqual(debugEvent.title, sdkEvent.eventName)
        XCTAssertEqual(debugEvent.typeLabel, "internal")
        XCTAssertTrue(debugEvent.properties.map(\.key).contains("mobile_content_id"))
    }

    func testFlatten_sortsKeysAndCapsOversizedNestedMaps() {
        var huge: [String: Any] = [:]
        for index in 1...30 {
            huge["k\(index)"] = index
        }

        let rows = mapper.flatten(["nested": huge, "alpha": "z"])

        XCTAssertEqual(rows.first?.key, "alpha")
        XCTAssertEqual(rows[1].value, "{30 keys}")
    }

    func testFlatten_truncatesLongStringValues() {
        let rows = mapper.flatten(["blob": String(repeating: "x", count: 500)])

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].value.count, 401)
        XCTAssertTrue(rows[0].value.hasSuffix("…"))
    }
}

// swiftlint:enable all
