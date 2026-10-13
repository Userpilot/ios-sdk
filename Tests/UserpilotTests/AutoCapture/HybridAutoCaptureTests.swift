//
//  HybridAutoCaptureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises native hooks in one Hybrid instance: source metadata, control values and screen identity.
//

import SwiftUI
import XCTest
@testable import Userpilot

final class HybridAutoCaptureTests: XCTestCase {
    private var owner: MockUserpilot!
    private var events: [Event] = []

    override func setUp() {
        super.setUp()
        owner = MockUserpilot.make(config: Userpilot.Config(token: "HYBRID-\(UUID().uuidString)")
            .defaultInstance(false).appFramework(.Hybrid))
        _ = owner.autoCaptureCoordinator
        owner.config.enableInteractionAutoCapture = true
        owner.config.enableInteractionValueCapture = true
        owner.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
    }

    override func tearDown() {
        owner.analyticsPublisher.onPublish = nil
        owner = nil
        events = []
        super.tearDown()
    }

    func testNativeAndHostedControls_keepTheirOwnFrameworkAndValueRules() throws {
        let nativeRoot = UIView()
        let host = UIHostingController(rootView: EmptyView())
        let nativeStepper = UIStepper()
        let hostedStepper = UIStepper()
        nativeRoot.addSubview(nativeStepper)
        host.view.addSubview(hostedStepper)
        nativeStepper.value = 3
        hostedStepper.value = 4

        nativeStepper.captureControlInteraction(action: nil, target: nil, event: nil, owner: owner)
        hostedStepper.captureControlInteraction(action: nil, target: nil, event: nil, owner: owner)

        XCTAssertEqual(events.count, 2)
        let native = try XCTUnwrap(events.first?.properties)
        let hosted = try XCTUnwrap(events.last?.properties)
        XCTAssertEqual(native["ui_framework"] as? String, "UIKit")
        XCTAssertEqual(native["selected_value"] as? Double, 3)
        XCTAssertEqual(hosted["ui_framework"] as? String, "SwiftUI")
        XCTAssertNil(hosted["selected_value"], "SwiftUI's proxy stepper cannot provide the logical value")
    }

    func testDeferredControl_keepsSourceWhenMovedBeforeDelivery() {
        let nativeRoot = UIView()
        let host = UIHostingController(rootView: EmptyView())
        let slider = UISlider()
        nativeRoot.addSubview(slider)
        slider.captureControlInteraction(action: nil, target: nil, event: nil, owner: owner)
        XCTAssertTrue(events.isEmpty)

        host.view.addSubview(slider)
        owner.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.properties?["ui_framework"] as? String, "UIKit")
    }

    func testScreenHooks_keepNativeClassAndHostedLogicalName() throws {
        let native = HybridNativeController()
        let host = UIHostingController(rootView: EmptyView())
        host.userpilotSwiftUIScreenName = "SwiftUI home"
        owner.attachToViewController(native)
        owner.attachToViewController(host)
        owner.config.enableScreenAutoCapture = true
        AutoCaptureSwizzler.swizzleUIKitScreenTracking()

        native.viewWillAppear(false)
        XCTAssertEqual(events.count, 1)
        let nativeEvent = try XCTUnwrap(events.first)
        XCTAssertEqual(nativeEvent.screenTitle, native.screenClassName)
        XCTAssertEqual(nativeEvent.properties?["ui_framework"] as? String, "UIKit")

        let published = expectation(description: "Hosted screen passes the deferred native hook")
        owner.analyticsPublisher.onPublish = { [weak self] event in
            self?.events.append(event)
            published.fulfill()
        }
        host.viewWillAppear(false)
        wait(for: [published], timeout: 2)

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.last?.screenTitle, "SwiftUI home")
        XCTAssertEqual(events.last?.properties?["ui_framework"] as? String, "SwiftUI")
    }
}

private final class HybridNativeController: UIViewController {}
