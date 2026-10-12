//
//  SwiftUIButtonPrivacyTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies privacy carriers at the window-tap publication boundary, including existing metadata.
//

import XCTest
@testable import Userpilot

private final class PrivacyHostingView: UIView {}

final class SwiftUIButtonPrivacyTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var window: UIWindow!
    private var tapped: UILabel!
    private var carrier: UIView!
    private var events: [Event] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("SwiftUI button capture runs on iOS 26 and later only")
        }
        SwiftUICaptureHealth._resetForTesting()
        let config = Userpilot.Config(token: "PRIVACY-\(UUID().uuidString)").appFramework(.SwiftUI)
        userpilot = MockUserpilot(config: config)
        // Resolve before opting in: these publication fixtures do not need process-wide hooks.
        _ = userpilot.autoCaptureCoordinator
        config.enableInteractionAutoCapture(true).enableSwiftUIButtonAutoCapture(true)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let hostingView = PrivacyHostingView(frame: window.bounds)
        window.addSubview(hostingView)
        carrier = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 100))
        hostingView.addSubview(carrier)
        tapped = UILabel(frame: hostingView.bounds)
        tapped.text = "Existing UIKit title"
        tapped.accessibilityIdentifier = "button-id"
        hostingView.addSubview(tapped)
        window.isHidden = false
        userpilot.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
    }

    override func tearDown() {
        UserpilotRuntime.shared.scanCache.stop()
        window?.isHidden = true
        tapped = nil
        carrier = nil
        window = nil
        userpilot = nil
        events = []
        SwiftUICaptureHealth._resetForTesting()
        super.tearDown()
    }

    func testIgnoredSibling_dropsWholeClickEvenWithExistingTextAndIdentifier() {
        carrier.userpilotIgnoreInteractions = true

        tap(at: CGPoint(x: 40, y: 60))

        XCTAssertTrue(events.isEmpty)
    }

    func testIgnoredDescendant_dropsWholeClickWhenIdentifierAloneWouldPublish() {
        tapped.text = nil
        tapped.addSubview(carrier)
        carrier.userpilotIgnoreInteractions = true

        tap(at: CGPoint(x: 40, y: 60))

        XCTAssertTrue(events.isEmpty)
    }

    func testIgnoreOutsideTap_doesNotSuppressAdjacentClick() throws {
        carrier.userpilotIgnoreInteractions = true

        tap(at: CGPoint(x: 220, y: 150))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(try XCTUnwrap(events.first?.properties)[Constants.AutoCapture.targetText] as? String,
                       "Existing UIKit title")
    }

    func testRemovingIgnore_restoresOriginalPayload() throws {
        tap(at: CGPoint(x: 40, y: 60))
        let original = try XCTUnwrap(events.first?.properties)
        carrier.userpilotIgnoreInteractions = true
        tap(at: CGPoint(x: 40, y: 60))
        carrier.userpilotIgnoreInteractions = false
        tap(at: CGPoint(x: 40, y: 60))

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(try XCTUnwrap(events.last?.properties) as NSDictionary, original as NSDictionary)
    }

    func testStoppedOwner_doesNotReadTitleOrPublish() {
        userpilot.autoCaptureCoordinator.stopAutoCapture()

        tap(at: CGPoint(x: 40, y: 60))

        XCTAssertTrue(events.isEmpty)
    }

    private func tap(at point: CGPoint) {
        window.handleRegularViewTap(on: tapped, target: userpilot, window: window, point: point)
    }
}
