//
//  AutoCaptureForwardingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 12/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  MI-007/MI-011/MI-014: real coordinators with recording publishers, without sockets.
//

import XCTest
@testable import Userpilot

final class AutoCaptureForwardingTests: XCTestCase {
    private var host: MockUserpilot!
    private var vendor: MockUserpilot!
    private var hostEvents: [Event] = []
    private var vendorEvents: [Event] = []

    override func tearDown() {
        host = nil
        vendor = nil
        hostEvents = []
        vendorEvents = []
        super.tearDown()
    }

    func testForwardingOff_publishesOnlyToOwner() {
        configure(forward: false)
        capture(vendor)
        XCTAssertEqual(vendorEvents.count, 1)
        XCTAssertTrue(hostEvents.isEmpty)
    }

    func testForwardingOn_publishesExactlyOnceToEachDestinationWithSamePayload() throws {
        configure(forward: true)
        capture(vendor)
        XCTAssertEqual(vendorEvents.count, 1)
        XCTAssertEqual(hostEvents.count, 1)
        let local = try XCTUnwrap(vendorEvents.first)
        let forwarded = try XCTUnwrap(hostEvents.first)
        XCTAssertEqual(forwarded.properties as NSDictionary?, local.properties as NSDictionary?)
        XCTAssertEqual(forwarded.screen as NSDictionary?, local.screen as NSDictionary?)
        XCTAssertEqual(forwarded.interactionEventName, local.interactionEventName)
    }

    func testDefaultOwner_neverForwardsToItself() {
        configure(forward: true)
        capture(host)
        XCTAssertEqual(hostEvents.count, 1)
        XCTAssertTrue(vendorEvents.isEmpty)
    }

    func testDisabledOwner_emitsNeitherLocalNorForwardedEvent() {
        configure(forward: true, vendorCapture: false)
        capture(vendor)
        XCTAssertTrue(vendorEvents.isEmpty)
        XCTAssertTrue(hostEvents.isEmpty)
    }

    func testStoppedOwner_emitsNothingAndResumePermitsOneEventPerDestination() {
        configure(forward: true)
        vendor.stopAutoCapture()
        capture(vendor)
        XCTAssertTrue(vendorEvents.isEmpty)
        XCTAssertTrue(hostEvents.isEmpty)
        vendor.resumeAutoCapture()
        capture(vendor)
        XCTAssertEqual(vendorEvents.count, 1)
        XCTAssertEqual(hostEvents.count, 1)
    }

    func testDefaultCaptureSetting_doesNotDisableExplicitForwardingOptIn() {
        configure(forward: true, hostCapture: false)
        capture(host)
        XCTAssertTrue(hostEvents.isEmpty)
        capture(vendor)
        XCTAssertEqual(vendorEvents.count, 1)
        XCTAssertEqual(hostEvents.count, 1)
    }

    func testExplicitTrack_bypassesAutoCaptureForwarding() {
        configure(forward: true)
        vendor.track(eventName: "Explicit vendor event")
        XCTAssertEqual(vendorEvents.count, 1)
        XCTAssertTrue(hostEvents.isEmpty)
    }

    private func configure(forward: Bool, hostCapture: Bool = true, vendorCapture: Bool = true) {
        host = MockUserpilot.make(config: Userpilot.Config(token: "HOST-\(UUID().uuidString)")
            .allowReceiveEventsFromExternalSource(forward)
            .enableInteractionAutoCapture(hostCapture))
        vendor = MockUserpilot.make(config: Userpilot.Config(token: "VENDOR-\(UUID().uuidString)")
            .defaultInstance(false)
            .enableInteractionAutoCapture(vendorCapture))
        host.analyticsPublisher.onPublish = { [weak self] in self?.hostEvents.append($0) }
        vendor.analyticsPublisher.onPublish = { [weak self] in self?.vendorEvents.append($0) }
    }

    private func capture(_ owner: MockUserpilot) {
        owner.autoCaptureCoordinator.handleInteractionEvent(
            InteractionPayload(interactionType: .tap, elementType: "UIButton")
        )
    }
}
