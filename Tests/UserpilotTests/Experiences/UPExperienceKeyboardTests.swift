//
//  UPExperienceKeyboardTests.swift
//  Userpilot SDK
//
//  The body scrolls the focused field above the keyboard when the part left uncovered still holds the field
//  with the usual spacing to spare. Otherwise a card moves up onto the keyboard, and full-screen content keeps
//  scrolling and rises only by what is missing; neither rises so far that the field passes under the top bars.
//  A tap anywhere but on a text input closes the keyboard.
//

import UIKit
import XCTest
@testable import Userpilot

final class UPExperienceKeyboardTests: XCTestCase {
    func testABodyStillHoldingTheFieldScrollsWithTheCoveredPartAddedUnderIt() {
        XCTAssertEqual(avoidance(bodyHeight: 300, covered: 100, fieldHeight: 50), .scroll(bottomInset: 100))
    }

    func testAFieldThatJustFitsWithTheSpacingStillScrolls() {
        XCTAssertEqual(avoidance(bodyHeight: 166, covered: 100, fieldHeight: 50), .scroll(bottomInset: 100))
    }

    func testAKeyboardClearOfTheBodyAddsNothing() {
        XCTAssertEqual(avoidance(bodyHeight: 300, covered: 0, fieldHeight: 50), .scroll(bottomInset: 0))
    }

    func testABodyTooShortMovesTheWholeCardOntoTheKeyboard() {
        XCTAssertEqual(avoidance(bodyHeight: 120, covered: 70, fieldHeight: 50), .move(distance: 110, bottomInset: 0))
    }

    func testAMoveStopsBeforeTheFocusedFieldPassesUnderTheTopBars() {
        XCTAssertEqual(avoidance(bodyHeight: 120, covered: 70, fieldHeight: 50, fieldRoom: 60),
                       .move(distance: 60, bottomInset: 0))
    }

    func testAFieldAlreadyAtTheTopBarsKeepsTheCardInPlace() {
        XCTAssertEqual(avoidance(bodyHeight: 120, covered: 70, fieldHeight: 50, fieldRoom: -10),
                       .move(distance: 0, bottomInset: 0))
    }

    func testFullScreenContentScrollsTheFieldToTheBodysTopAndRisesOnlyByWhatIsMissing() {
        XCTAssertEqual(avoidance(bodyHeight: 120, covered: 70, fieldHeight: 50, fieldRoom: 60, fullScreen: true),
                       .move(distance: 70 + 50 + 16 - 120, bottomInset: 70))
    }

    func testFullScreenContentStopsRisingBeforeTheFieldPassesUnderTheTopBars() {
        XCTAssertEqual(avoidance(bodyHeight: 120, covered: 70, fieldHeight: 50, fieldRoom: 10, fullScreen: true),
                       .move(distance: 10, bottomInset: 70))
    }

    /// A body from 258 to 888 under a status bar ending at 84, as on a phone in landscape.
    func testAFullScreenBodyCountsTheFieldFromItsTop() {
        XCTAssertEqual(fieldRoom(fieldTop: 548, fullScreen: true), 258 - 84 - 16)
    }

    func testACardCountsAFieldInViewFromWhereItIs() {
        XCTAssertEqual(fieldRoom(fieldTop: 548, fullScreen: false), 548 - 84 - 16)
    }

    func testACardCountsAFieldScrolledUnderItsHeaderFromTheBodysTop() {
        XCTAssertEqual(fieldRoom(fieldTop: 100, fullScreen: false), 258 - 84 - 16)
    }

    func testACardCountsAFieldHiddenUnderItsFooterFromWhereTheBodyScrollsIt() {
        XCTAssertEqual(fieldRoom(fieldTop: 900, fullScreen: false), 888 - 240 - 84 - 16)
    }

    func testASingleLineFieldIsMeasuredByItsPaddedBox() {
        let line = CGRect(x: 0, y: 100, width: 200, height: 20)
        XCTAssertEqual(UPExperienceHostingController.fieldBox(around: line, singleLine: true),
                       CGRect(x: 0, y: 85, width: 200, height: 50))
        let tall = CGRect(x: 0, y: 100, width: 200, height: 40)
        XCTAssertEqual(UPExperienceHostingController.fieldBox(around: tall, singleLine: true),
                       CGRect(x: 0, y: 88, width: 200, height: 64))
    }

    func testAMultilineFieldIsItsOwnBox() {
        let area = CGRect(x: 0, y: 100, width: 200, height: 80)
        XCTAssertEqual(UPExperienceHostingController.fieldBox(around: area, singleLine: false), area)
    }

    func testATapInsideATextFieldKeepsTheKeyboard() {
        let field = UITextField()
        let inner = UIView()
        field.addSubview(inner)
        XCTAssertTrue(UPExperienceHostingController.isTextInput(field))
        XCTAssertTrue(UPExperienceHostingController.isTextInput(inner))
    }

    func testATapOnTheOpenTextBoxKeepsTheKeyboard() {
        XCTAssertTrue(UPExperienceHostingController.isTextInput(UITextView()))
    }

    func testATapOnReadOnlyTextClosesTheKeyboard() {
        let links = UITextView()
        links.isEditable = false
        XCTAssertFalse(UPExperienceHostingController.isTextInput(links))
    }

    func testATapOnAnythingElseClosesTheKeyboard() {
        let card = UIView()
        let button = UIButton()
        card.addSubview(button)
        XCTAssertFalse(UPExperienceHostingController.isTextInput(button))
        XCTAssertFalse(UPExperienceHostingController.isTextInput(card))
        XCTAssertFalse(UPExperienceHostingController.isTextInput(nil))
    }

    /// A card whose content ends at 260, over a keyboard whose top is at 150.
    private func avoidance(
        bodyHeight: CGFloat, covered: CGFloat, fieldHeight: CGFloat,
        fieldRoom: CGFloat = .greatestFiniteMagnitude, fullScreen: Bool = false
    ) -> UPExperienceHostingController.KeyboardAvoidance {
        UPExperienceHostingController.keyboardAvoidance(
            bodyHeight: bodyHeight, covered: covered, fieldHeight: fieldHeight, cardBottom: 260, keyboardTop: 150,
            fieldRoom: fieldRoom, fullScreen: fullScreen)
    }

    /// A 240-point field at `fieldTop`, in a body from 258 to 888 under a status bar ending at 84.
    private func fieldRoom(fieldTop: CGFloat, fullScreen: Bool) -> CGFloat {
        UPExperienceHostingController.fieldRoom(
            field: CGRect(x: 0, y: fieldTop, width: 300, height: 240),
            body: CGRect(x: 0, y: 258, width: 300, height: 630),
            safeTop: 84, fullScreen: fullScreen)
    }
}
