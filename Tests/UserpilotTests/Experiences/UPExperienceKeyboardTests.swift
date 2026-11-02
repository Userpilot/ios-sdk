//
//  UPExperienceKeyboardTests.swift
//  Userpilot SDK
//
//  The body scrolls the focused field above the keyboard when the part left uncovered still holds the field
//  with the usual spacing to spare; otherwise the whole card moves up onto the keyboard.
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
        XCTAssertEqual(avoidance(bodyHeight: 120, covered: 70, fieldHeight: 50), .move(distance: 110))
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

    /// A card whose content ends at 260, over a keyboard whose top is at 150.
    private func avoidance(bodyHeight: CGFloat, covered: CGFloat, fieldHeight: CGFloat)
        -> UPExperienceHostingController.KeyboardAvoidance {
        UPExperienceHostingController.keyboardAvoidance(
            bodyHeight: bodyHeight, covered: covered, fieldHeight: fieldHeight, cardBottom: 260, keyboardTop: 150)
    }
}
