//
//  InteractionPayloadTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class InteractionPayloadTests: XCTestCase {

    func testInteractionTypesMapToBackendEventTypes() {
        XCTAssertEqual(InteractionType.tap.toInteractionEventType(), .tap)
        XCTAssertEqual(InteractionType.gesture.toInteractionEventType(), .tap)
        XCTAssertEqual(InteractionType.textFieldChanged.toInteractionEventType(), .textChange)
        XCTAssertEqual(InteractionType.textViewChanged.toInteractionEventType(), .textChange)
        XCTAssertEqual(InteractionType.tableViewCellSelected.toInteractionEventType(), .selectionChange)
        XCTAssertEqual(InteractionType.collectionViewItemSelected.toInteractionEventType(), .selectionChange)
        XCTAssertEqual(InteractionType.pickerViewChanged.toInteractionEventType(), .selectionChange)
        XCTAssertEqual(InteractionType.tabSelected.toInteractionEventType(), .selectionChange)
        XCTAssertEqual(InteractionType.segmentChanged.toInteractionEventType(), .selectionChange)
        XCTAssertEqual(InteractionType.pageControlChanged.toInteractionEventType(), .selectionChange)
        XCTAssertEqual(InteractionType.switchChanged.toInteractionEventType(), .valueChange)
        XCTAssertEqual(InteractionType.sliderChanged.toInteractionEventType(), .valueChange)
        XCTAssertEqual(InteractionType.stepperChanged.toInteractionEventType(), .valueChange)
        XCTAssertEqual(InteractionType.datePickerChanged.toInteractionEventType(), .valueChange)
        XCTAssertEqual(InteractionType.viewPresented.toInteractionEventType(), .viewPresented)
    }

    func testInteractionPayloadDictionaryIncludesOnlyPresentFields() {
        var payload = InteractionPayload(interactionType: .tap, elementType: "UIButton")
        payload.elementText = "Continue"
        payload.accessibilityLabel = "Continue label"
        payload.accessibilityIdentifier = "continue_button"
        payload.hierarchy = "Root/UIButton[0]"
        payload.targetAction = "continueTapped:"
        payload.ownerTargetClass = "ViewController"
        payload.targetViewName = "continueButton"
        payload.placeholder = "Placeholder"
        payload.dialogTitle = "Dialog"
        payload.dialogMessage = "Message"
        payload.section = 2
        payload.row = 4

        let dict = payload.toDictionary()

        XCTAssertEqual(dict[Constants.AutoCapture.targetClass] as? String, "UIButton")
        XCTAssertEqual(dict[Constants.AutoCapture.targetText] as? String, "Continue")
        XCTAssertEqual(dict[Constants.AutoCapture.accessibilityLabel] as? String, "Continue label")
        XCTAssertEqual(dict[Constants.AutoCapture.accessibilityIdentifier] as? String, "continue_button")
        XCTAssertEqual(dict[Constants.AutoCapture.hierarchy] as? String, "Root/UIButton[0]")
        XCTAssertEqual(dict[Constants.AutoCapture.targetAction] as? String, "continueTapped:")
        XCTAssertEqual(dict[Constants.AutoCapture.ownerTargetClass] as? String, "ViewController")
        XCTAssertEqual(dict[Constants.AutoCapture.targetViewName] as? String, "continueButton")
        XCTAssertEqual(dict[Constants.AutoCapture.placeholder] as? String, "Placeholder")
        XCTAssertEqual(dict[Constants.AutoCapture.dialogTitle] as? String, "Dialog")
        XCTAssertEqual(dict[Constants.AutoCapture.dialogMessage] as? String, "Message")
        XCTAssertEqual(dict[Constants.AutoCapture.section] as? Int, 2)
        XCTAssertEqual(dict[Constants.AutoCapture.selectedIndex] as? Int, 4)
    }

    func testInteractionPayloadSourceDictionaryReturnsControlProperties() {
        var payload = InteractionPayload(interactionType: .sliderChanged, elementType: "UISlider")
        payload.sourceProperties = ["value": 0.5, "is_checked": true]

        let source = payload.toSourceDictionary()

        XCTAssertEqual(source["value"] as? Double, 0.5)
        XCTAssertEqual(source["is_checked"] as? Bool, true)
    }

    func testScreenTrackingPayloadDictionaryIncludesManualAndOptionalValues() {
        var payload = ScreenTrackingPayload(
            currentScreen: "Home",
            screenClass: "HomeViewController",
            screenType: "UIViewController",
            navigationTitle: "Dashboard",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: "home_vc",
            vcAccessibilityLabel: "Home VC"
        )
        payload.screenNameMatchesPreviousScreen = true
        payload.appFramework = .SwiftUI

        let dict = payload.toDictionary()

        XCTAssertEqual(dict[Constants.AutoCapture.screenName] as? String, "Home")
        XCTAssertEqual(dict[Constants.AutoCapture.screenClass] as? String, "HomeViewController")
        XCTAssertEqual(dict[Constants.AutoCapture.screenType] as? String, "UIViewController")
        XCTAssertEqual(dict[Constants.AutoCapture.navigationTitle] as? String, "Dashboard")
        XCTAssertEqual(dict[Constants.AutoCapture.vcAccessibilityIdentifier] as? String, "home_vc")
        XCTAssertEqual(dict[Constants.AutoCapture.vcAccessibilityLabel] as? String, "Home VC")
        XCTAssertEqual(dict[Constants.AutoCapture.screenNameMatchesPreviousScreen] as? Bool, true)
        XCTAssertEqual(dict[Constants.AutoCapture.uiFramework] as? String, Userpilot.AppFramework.SwiftUI.rawValue)
        XCTAssertEqual(dict[Constants.AutoCapture.source] as? String, Constants.AutoCapture.autoCaptureSourceValue)
    }

    func testManualScreenTrackingPayloadUsesScreenTitleAsNameAndClass() {
        let payload = ScreenTrackingPayload(screenTitle: "Manual Screen", appFramework: .UIKit)
        let dict = payload.toDictionary()

        XCTAssertEqual(payload.currentScreen, "Manual Screen")
        XCTAssertEqual(payload.screenClass, "Manual Screen")
        XCTAssertEqual(dict[Constants.AutoCapture.uiFramework] as? String, Userpilot.AppFramework.UIKit.rawValue)
    }
}
