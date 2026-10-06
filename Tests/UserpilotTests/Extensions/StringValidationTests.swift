//
//  StringValidationTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins the existing native survey answer rules independently of field styling.
//

import UIKit
import XCTest
@testable import Userpilot

final class StringValidationTests: XCTestCase {
    func testValidation_preservesNativeKeyboardRules() {
        XCTAssertTrue("a@example.com".isValidAnswer(keyboardType: .emailAddress))
        XCTAssertFalse("invalid".isValidAnswer(keyboardType: .emailAddress))
        XCTAssertFalse("123".isValidAnswer(keyboardType: .phonePad))
        XCTAssertTrue("abcd".isValidAnswer(keyboardType: .phonePad))
        XCTAssertTrue("-1.25".isValidAnswer(keyboardType: .decimalPad))
        XCTAssertFalse("abc".isValidAnswer(keyboardType: .numberPad))
        XCTAssertTrue(" ".isValidAnswer(keyboardType: .default))
        XCTAssertFalse("".isValidAnswer(keyboardType: .default))
    }

    func testFieldValidation_preservesMissingTextFallback() {
        let field = UITextField()
        field.keyboardType = .emailAddress
        field.text = nil
        XCTAssertFalse(field.isValidAnswer())
        field.text = "a@example.com"
        XCTAssertTrue(field.isValidAnswer())
    }
}
