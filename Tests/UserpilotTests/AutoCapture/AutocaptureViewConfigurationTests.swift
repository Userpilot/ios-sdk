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

    func testDialogTextIsPublishedRawWhenRedactionIsNotRequested() {
        let alert = UIAlertController(
            title: "Delete account?",
            message: "This cannot be undone",
            preferredStyle: .alert
        )

        let dialogText = alert.userpilotDialogText()

        XCTAssertEqual(dialogText.title, "Delete account?")
        XCTAssertEqual(dialogText.message, "This cannot be undone")
    }

    func testDialogTextIsRedactedWhenRedactTextIsSetOnTheAlert() {
        let alert = UIAlertController(
            title: "Delete account?",
            message: "This cannot be undone",
            preferredStyle: .alert
        )
        alert.view.userpilotRedactText = true

        let dialogText = alert.userpilotDialogText()

        XCTAssertEqual(dialogText.title, AutoCaptureConstants.reductText)
        XCTAssertEqual(dialogText.message, AutoCaptureConstants.reductText)
    }

    func testDialogTextKeepsNilFieldsWhenRedacted() {
        let alert = UIAlertController(title: "Delete account?", message: nil, preferredStyle: .alert)
        alert.view.userpilotRedactText = true

        let dialogText = alert.userpilotDialogText()

        XCTAssertEqual(dialogText.title, AutoCaptureConstants.reductText)
        XCTAssertNil(dialogText.message)
    }

    func testResolvedInteractionTextOmitsWhenCaptureDisabledWithoutOwner() {
        let view = UIView()
        // Without a resolvable Userpilot owner, capture defaults to enabled — opt-in still redacts.
        XCTAssertEqual(view.resolvedInteractionText("Visible"), "Visible")
        view.userpilotRedactText = true
        XCTAssertEqual(view.resolvedInteractionText("Visible"), AutoCaptureConstants.reductText)
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
