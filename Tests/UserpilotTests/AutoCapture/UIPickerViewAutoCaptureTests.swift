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

    func testSelectedTitlePrefersDelegateTitleWithoutReadingLaterFallbacks() {
        let picker = UIPickerView()
        let delegate = PickerTitleDelegate()
        delegate.title = " Banana "
        delegate.attributedTitle = "Orange"
        picker.delegate = delegate

        XCTAssertEqual(picker.userpilotResolvedSelectedTitle(forRow: 0, component: 0), "Banana")
        XCTAssertEqual(delegate.reads, ["title"])
    }

    func testSelectedTitleFallsBackFromBlankTitleToAttributedTitle() {
        let picker = UIPickerView()
        let delegate = PickerTitleDelegate()
        delegate.title = " \n "
        delegate.attributedTitle = " Orange "
        picker.delegate = delegate

        XCTAssertEqual(picker.userpilotResolvedSelectedTitle(forRow: 0, component: 0), "Orange")
        XCTAssertEqual(delegate.reads, ["title", "attributed"])
    }

    func testRowTextPrefersNativeTextBeforeAccessibilityAndDescendants() {
        let row = UILabel()
        row.text = "Native"
        row.accessibilityLabel = "Accessibility"
        let child = UILabel()
        child.text = "Child"
        row.addSubview(child)

        XCTAssertEqual(UIPickerView.userpilotExtractPickerRowText(from: row), "Native")
    }
}

private final class PickerTitleDelegate: NSObject, UIPickerViewDelegate {
    var title: String?
    var attributedTitle: String?
    var reads: [String] = []

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        reads.append("title")
        return title
    }

    func pickerView(
        _ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int
    ) -> NSAttributedString? {
        reads.append("attributed")
        return attributedTitle.map(NSAttributedString.init(string:))
    }
}
