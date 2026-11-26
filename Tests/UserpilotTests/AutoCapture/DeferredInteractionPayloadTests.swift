//
//  DeferredInteractionPayloadTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Debounced slider and text hooks build their payload once, when the debounce delivers.
//

import XCTest
@testable import Userpilot

final class DeferredInteractionPayloadTests: XCTestCase {
    private var owner: MockUserpilot!
    private var events: [Event] = []

    override func setUp() {
        super.setUp()
        owner = MockUserpilot.make(config: Userpilot.Config(token: "DEFERRED-\(UUID().uuidString)")
            .defaultInstance(false).appFramework(.UIKit).enableInteractionAutoCapture())
        owner.config.enableInteractionValueCapture = true
        owner.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
    }

    override func tearDown() {
        owner.analyticsPublisher.onPublish = nil
        owner = nil
        events = []
        super.tearDown()
    }

    func testSliderDrag_publishesOnePayloadBuiltAtDeliveryWithTheFinalValue() throws {
        let container = UIView()
        let slider = UISlider()
        container.addSubview(slider)

        for value in [Float(0.1), 0.4, 0.7, 0.9] {
            slider.value = value
            slider.captureControlInteraction(action: nil, target: nil, event: nil, owner: owner)
        }
        slider.accessibilityIdentifier = "volume_slider"
        owner.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(events.count, 1)
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.selectedValue] as? Float, 0.9)
        XCTAssertEqual(
            properties[Constants.AutoCapture.accessibilityIdentifier] as? String, "volume_slider",
            "Identity is read when the debounce delivers, not on every value change")
    }

    func testSliderReleasedBeforeDelivery_publishesNothing() {
        weak var releasedSlider: UISlider?
        autoreleasepool {
            let slider = UISlider()
            releasedSlider = slider
            slider.captureControlInteraction(action: nil, target: nil, event: nil, owner: owner)
        }
        XCTAssertNil(releasedSlider, "Precondition: the pending interaction does not retain the slider")

        owner.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertTrue(events.isEmpty)
    }

    func testTextFieldTyping_publishesOnePayloadBuiltAtDeliveryWithTheLatestLength() throws {
        let field = UITextField()
        owner.attachToView(field)

        for text in ["a", "ab", "abc"] {
            field.text = text
            field.cacheTextFieldChanged()
        }
        field.accessibilityIdentifier = "email_field"
        owner.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(events.count, 1)
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.textLength] as? Int, 3)
        XCTAssertEqual(properties[Constants.AutoCapture.hasText] as? Bool, true)
        XCTAssertEqual(properties[Constants.AutoCapture.accessibilityIdentifier] as? String, "email_field")
    }

    func testTextFieldReleasedBeforeDelivery_publishesNothing() {
        weak var releasedField: UITextField?
        autoreleasepool {
            let field = UITextField()
            releasedField = field
            owner.attachToView(field)
            field.text = "abc"
            field.cacheTextFieldChanged()
        }
        XCTAssertNil(releasedField, "Precondition: the pending interaction does not retain the field")

        owner.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertTrue(events.isEmpty)
    }
}
