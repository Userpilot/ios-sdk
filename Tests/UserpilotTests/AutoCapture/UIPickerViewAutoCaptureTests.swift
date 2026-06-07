//
//  UIPickerViewAutoCaptureTests.swift
//  UserpilotTests
//
//  Created by OpenAI Codex on 13/05/2026.
//

import XCTest
@testable import Userpilot

final class UIPickerViewAutoCaptureTests: XCTestCase {

    func testPickerRowTextUsesUILabelText() {
        let rowView = UIView()
        let label = UILabel()
        label.text = "Banana"
        rowView.addSubview(label)

        XCTAssertEqual(UIPickerView.userpilotExtractPickerRowText(from: rowView), "Banana")
    }

    func testPickerRowTextUsesNestedAccessibilityLabelForSwiftUIHostedRows() {
        let rowView = UIView()
        let hostedTextView = UIView()
        hostedTextView.accessibilityLabel = "Orange"
        rowView.addSubview(hostedTextView)

        XCTAssertEqual(UIPickerView.userpilotExtractPickerRowText(from: rowView), "Orange")
    }

    func testPickerRowTextUsesAccessibilityElementsForSwiftUIHostedRows() {
        let rowView = UIView()
        let element = UIAccessibilityElement(accessibilityContainer: rowView)
        element.accessibilityLabel = "Pineapple"
        rowView.accessibilityElements = [element]

        XCTAssertEqual(UIPickerView.userpilotExtractPickerRowText(from: rowView), "Pineapple")
    }
}
