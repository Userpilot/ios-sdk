//
//  AutocaptureViewConfigurationTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class AutocaptureViewConfigurationTests: XCTestCase {

    func testSettersUpdateResponderAssociatedFlags() {
        let view = UIView()

        XCTAssertFalse(view.userpilotIgnoreInteractions)
        XCTAssertFalse(view.userpilotIgnoreInnerHierarchy)
        XCTAssertFalse(view.userpilotRedactText)
        XCTAssertFalse(view.userpilotRedactAccessibilityLabel)

        AutocaptureViewConfiguration.setIgnoreInteractions(true, for: view)
        AutocaptureViewConfiguration.setIgnoreInnerHierarchy(true, for: view)
        AutocaptureViewConfiguration.setRedactText(true, for: view)
        AutocaptureViewConfiguration.setRedactAccessibilityLabel(true, for: view)

        XCTAssertTrue(view.userpilotIgnoreInteractions)
        XCTAssertTrue(view.userpilotIgnoreInnerHierarchy)
        XCTAssertTrue(view.userpilotRedactText)
        XCTAssertTrue(view.userpilotRedactAccessibilityLabel)

        AutocaptureViewConfiguration.setIgnoreInteractions(false, for: view)
        AutocaptureViewConfiguration.setIgnoreInnerHierarchy(false, for: view)
        AutocaptureViewConfiguration.setRedactText(false, for: view)
        AutocaptureViewConfiguration.setRedactAccessibilityLabel(false, for: view)

        XCTAssertFalse(view.userpilotIgnoreInteractions)
        XCTAssertFalse(view.userpilotIgnoreInnerHierarchy)
        XCTAssertFalse(view.userpilotRedactText)
        XCTAssertFalse(view.userpilotRedactAccessibilityLabel)
    }

    func testResponderClassDefaultsAreUsedUntilExplicitlyOverridden() {
        let view = DefaultIgnoredView()

        XCTAssertTrue(view.userpilotIgnoreInteractions)
        XCTAssertTrue(view.userpilotIgnoreInnerHierarchy)

        view.userpilotIgnoreInteractions = false
        view.userpilotIgnoreInnerHierarchy = false

        XCTAssertFalse(view.userpilotIgnoreInteractions)
        XCTAssertFalse(view.userpilotIgnoreInnerHierarchy)
    }
}

private class DefaultIgnoredView: UIView {
    override class var userpilotIgnoreInteractionsDefault: Bool { true }
    override class var userpilotIgnoreInnerHierarchyDefault: Bool { true }
}
