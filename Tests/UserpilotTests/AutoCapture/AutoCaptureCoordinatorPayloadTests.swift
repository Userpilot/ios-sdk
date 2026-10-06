//
//  AutoCaptureCoordinatorPayloadTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins coordinator payloads before extracting pure interaction and tab formatting.
//

import XCTest
@testable import Userpilot

final class AutoCaptureCoordinatorPayloadTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var coordinator: AutoCaptureCoordinator!
    private var tracker: MockPayloadScreenTracker!
    private var events: [Event] = []

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "PAYLOAD-\(UUID().uuidString)")
            .appFramework(.UIKit).defaultInstance(false))
        tracker = MockPayloadScreenTracker()
        tracker.payload = ScreenTrackingPayload(screenTitle: "HomeVC")
        userpilot.container.register(ScreenNameTracking.self, value: tracker!)
        // Construct while capture is disabled; these boundary tests do not install UIKit hooks.
        coordinator = AutoCaptureCoordinator(container: userpilot.container)
        userpilot.config.enableInteractionAutoCapture = true
        userpilot.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
    }

    override func tearDown() {
        userpilot.analyticsPublisher.onPublish = nil
        coordinator = nil
        tracker = nil
        userpilot = nil
        events.removeAll()
        super.tearDown()
    }

    func testInteractionPayload_preservesSourcePrecedenceAndEnrichesSourceHierarchy() throws {
        var interaction = InteractionPayload(interactionType: .sliderChanged, elementType: "UISlider")
        interaction.elementText = "Original"
        interaction.accessibilityLabel = "Volume"
        interaction.accessibilityIdentifier = "volume"
        interaction.hierarchy = "Original"
        interaction.row = 2
        interaction.sourceProperties = [
            "target_class": "source-class", "target_text": "", "selected_index": 4,
            "raw_interaction_type": "source-kind", "ui_framework": "source-framework",
            "hierarchy": "Source;UnknownScreen", "custom": true
        ]

        coordinator.handleInteractionEvent(interaction)

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(event.properties as NSDictionary?, [
            "target_class": "source-class", "target_text": "", "selected_index": 4,
            "accessibility_label": "Volume", "accessibility_identifier": "volume",
            "raw_interaction_type": "source-kind", "ui_framework": "source-framework",
            "hierarchy": "Source;HomeVC;HomeVC", "custom": true
        ] as NSDictionary)
        XCTAssertEqual(event.screen as NSDictionary?, ["title": "HomeVC", "screen_name": "HomeVC"] as NSDictionary)
        XCTAssertEqual(event.interactionEventName, "value_change")
        XCTAssertEqual(tracker.reads, 1)
    }

    func testInteractionPayload_preservesEmptyTargetFieldsAndMissingHierarchy() throws {
        var interaction = InteractionPayload(interactionType: .tap, elementType: "")
        interaction.elementText = ""
        interaction.placeholder = ""

        coordinator.handleInteractionEvent(interaction)

        XCTAssertEqual(try XCTUnwrap(events.first?.properties) as NSDictionary, [
            "target_class": "", "target_text": "", "placeholder": "",
            "raw_interaction_type": "tap", "ui_framework": "UIKit"
        ] as NSDictionary)
    }

    func testInteractionPayload_keepsEmptyAndNonStringSourceHierarchies() throws {
        let hierarchies: [Any] = ["", 42]
        for hierarchy in hierarchies {
            var interaction = InteractionPayload(interactionType: .tap, elementType: "Button")
            interaction.hierarchy = "Original"
            interaction.sourceProperties = ["hierarchy": hierarchy]
            coordinator.handleInteractionEvent(interaction)
            XCTAssertEqual(try XCTUnwrap(events.last?.properties) as NSDictionary, [
                "target_class": "Button", "hierarchy": hierarchy,
                "raw_interaction_type": "tap", "ui_framework": "UIKit"
            ] as NSDictionary)
        }
    }

    func testInteractionPayload_withoutScreenRetainsCapturedHierarchy() throws {
        tracker.payload = nil
        var interaction = InteractionPayload(interactionType: .tap, elementType: "Button")
        interaction.hierarchy = "Button;UnknownScreen"

        coordinator.handleInteractionEvent(interaction)

        let event = try XCTUnwrap(events.first)
        XCTAssertNil(event.screen)
        XCTAssertEqual(event.properties as NSDictionary?, [
            "target_class": "Button", "hierarchy": "Button;UnknownScreen",
            "raw_interaction_type": "tap", "ui_framework": "UIKit"
        ] as NSDictionary)
    }

    func testTabPayload_trimsEscapesAndKeepsNativeFieldSet() throws {
        tracker.payload = ScreenTrackingPayload(screenTitle: " Home\"VC ")

        coordinator.handleTabSelected(name: "Reports", index: 3, screenClass: " Detail\"VC ")

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.properties as NSDictionary?, [
            "tab_name": "Reports", "tab_index": 3,
            "raw_interaction_type": "tab_selected", "ui_framework": "UIKit",
            "hierarchy": "Detail\\\"VC:attr__index=\"3\";Home\\\"VC"
        ] as NSDictionary)
        XCTAssertEqual(event.interactionEventName, "selection_change")
        XCTAssertEqual(
            event.screen as NSDictionary?, ["title": " Home\"VC ", "screen_name": " Home\"VC "] as NSDictionary
        )
        XCTAssertEqual(tracker.reads, 1)
    }

    func testTabPayload_blankLeafDoesNotInventHierarchy() throws {
        tracker.payload = nil

        coordinator.handleTabSelected(name: "", index: 0, screenClass: " \n ")

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.properties as NSDictionary?, [
            "tab_name": "", "tab_index": 0,
            "raw_interaction_type": "tab_selected", "ui_framework": "UIKit"
        ] as NSDictionary)
        XCTAssertNil(event.screen)
    }

    func testDialogPayload_retainsUnderlyingScreenAndDialogFields() throws {
        var dialog = ScreenTrackingPayload(screenTitle: "UIAlertController")
        dialog.isDialogPresentation = true
        dialog.alertTitle = "Confirm"
        dialog.alertMessage = "Continue?"

        coordinator.trackScreen(dialog)

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.properties as NSDictionary?, [
            "target_class": "UIAlertController", "dialog_title": "Confirm", "dialog_message": "Continue?",
            "hierarchy": "UIAlertController:attr__index=\"0\";HomeVC",
            "raw_interaction_type": "view_presented", "ui_framework": "UIKit"
        ] as NSDictionary)
        XCTAssertEqual(event.screen as NSDictionary?, ["title": "HomeVC", "screen_name": "HomeVC"] as NSDictionary)
        XCTAssertEqual(tracker.payload?.screenClass, "HomeVC")
    }

    func testDisabledAndStoppedCapture_doesNotReadScreenOrPublish() {
        let interaction = InteractionPayload(interactionType: .tap, elementType: "Button")
        userpilot.config.enableInteractionAutoCapture = false
        coordinator.handleInteractionEvent(interaction)
        coordinator.handleTabSelected(name: "Reports", index: 1, screenClass: "ReportsVC")
        userpilot.config.enableInteractionAutoCapture = true
        coordinator.stopAutoCapture()
        coordinator.handleInteractionEvent(interaction)
        coordinator.handleTabSelected(name: "Reports", index: 1, screenClass: "ReportsVC")

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(tracker.reads, 0)
    }
}

private final class MockPayloadScreenTracker: ScreenNameTracking {
    var payload: ScreenTrackingPayload?
    var reads = 0

    func updateScreen(with payload: ScreenTrackingPayload) { self.payload = payload }
    func getCurrentPayload() -> ScreenTrackingPayload? {
        reads += 1
        return payload
    }
    func buildScreenDictionary() -> [String: Any] { payload?.toDictionary() ?? [:] }
    func buildScreenDictionaryForEvent() -> [String: String] { payload?.toEventDictionary() ?? [:] }
    func buildScreenDictionaryForWrapperEvent() -> [String: String] { payload?.toWrapperEventDictionary() ?? [:] }
    func reset() { payload = nil }
}
