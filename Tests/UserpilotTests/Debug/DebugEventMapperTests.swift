//
//  DebugEventMapperTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
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
            properties: [Constants.AutoCapture.source: Constants.AutoCapture.manualCaptureSourceValue]
        )

        XCTAssertEqual(mapper.channelFor(event), .manual)
        XCTAssertEqual(mapper.fromAnalytics(event).title, "Home")
        XCTAssertEqual(mapper.fromAnalytics(event).typeLabel, "screen")
    }

    func testAutoCapturedScreen_mapsToAutoCaptureChannel() {
        let event = Event(
            type: .screen("Settings"),
            properties: [Constants.AutoCapture.source: Constants.AutoCapture.autoCaptureSourceValue]
        )

        XCTAssertEqual(mapper.channelFor(event), .autoCapture)
    }

    func testAutoCaptureInteraction_mapsToAutoCaptureChannel() {
        let event = Event(
            type: .autoCaptureEvent,
            properties: [Constants.AutoCapture.targetAction: "click"],
            interactionEventName: "button_click"
        )

        let debugEvent = mapper.fromAnalytics(event)

        XCTAssertEqual(debugEvent.channel, .autoCapture)
        XCTAssertEqual(debugEvent.title, "button_click")
        XCTAssertEqual(debugEvent.typeLabel, "auto_capture")
    }

    func testInternalSDKEvent_mapsToInternalChannel() {
        let sdkEvent = FlowExperienceActionEvent.seen(flowId: 42)

        let debugEvent = mapper.fromInternal(sdkEvent)

        XCTAssertEqual(debugEvent.channel, .internalSDK)
        XCTAssertEqual(debugEvent.title, sdkEvent.eventName)
        XCTAssertEqual(debugEvent.typeLabel, "internal")
        XCTAssertTrue(debugEvent.properties.map(\.key).contains("mobile_content_id"))
    }

    func testFlatten_sortsKeysAndPreservesEveryNestedEntry() {
        var huge: [String: Any] = [:]
        for index in 1...30 {
            huge["k\(index)"] = index
        }

        let rows = mapper.flatten(["nested": huge, "alpha": "z"])

        XCTAssertEqual(rows.first?.key, "alpha")
        for index in 1...30 {
            XCTAssertTrue(rows[1].value.contains("k\(index)"))
        }
    }

    func testFlatten_preservesLongUnicodeStringsAllPropertiesAndFullCollections() {
        let text = String(repeating: "🧪 مرحبا ", count: 150)
        let collection = Array(1...100)
        var source: [String: Any] = Dictionary(uniqueKeysWithValues: (1...100).map { ("key\($0)", $0) })
        source["text"] = text
        source["collection"] = collection
        source["null"] = NSNull()

        let rows = mapper.flatten(source)

        XCTAssertEqual(rows.count, 103)
        XCTAssertEqual(rows.map(\.key), source.keys.sorted())
        XCTAssertEqual(rows.first { $0.key == "text" }?.value, text)
        XCTAssertEqual(rows.first { $0.key == "collection" }?.value, String(describing: collection))
        XCTAssertEqual(rows.first { $0.key == "null" }?.value, "null")
    }
}

// swiftlint:enable all
