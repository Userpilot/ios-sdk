//
//  CellInteractionTextTests.swift
//  UserpilotTests
//
//  Verifies how `target_text` is resolved for `table_view_cell_selected` /
//  `collection_view_item_selected`. The regression covered here is a cell whose
//  content renders a large text blob (e.g. a JSON preview label): the touched
//  leaf view used to be the only text source, so tapping the blob published the
//  whole blob as `target_text` while the row's own title was never consulted.
//

import XCTest
@testable import Userpilot

final class CellInteractionTextTests: XCTestCase {

    // MARK: - Table view cell

    func testCellText_forDefaultCellTouchedOnNonTextSubview_usesCellTitle() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Events log"
        let icon = UIImageView()
        cell.contentView.addSubview(icon)

        XCTAssertEqual(cell.userpilotResolvedCellText(touchedView: icon), "Events log")
    }

    func testCellText_forDefaultCellTouchedOnDetailLabel_usesCellTitle() {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = "Language"
        cell.detailTextLabel?.text = "English"

        XCTAssertEqual(
            cell.userpilotResolvedCellText(touchedView: cell.detailTextLabel),
            "Language",
            "Row selection must publish the row title, not whichever label the finger landed on"
        )
    }

    func testCellText_forCustomCellTouchedOnJSONPreview_usesRowTitleNotTheBlob() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let title = UILabel()
        title.text = "Event"
        let jsonLabel = UILabel()
        jsonLabel.numberOfLines = 0
        jsonLabel.text = """
        {
          "event_name": "selection_change",
          "metadata": {
            "hierarchy": "UITableViewCell:attr__index=\\"2\\";UITableView:attr__index=\\"0\\""
          }
        }
        """
        cell.contentView.addSubview(title)
        cell.contentView.addSubview(jsonLabel)

        XCTAssertEqual(cell.userpilotResolvedCellText(touchedView: jsonLabel), "Event")
    }

    func testCellText_forCellWithOnlyLongText_isCollapsedAndBounded() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let blob = UILabel()
        blob.text = "{\n  \"event_name\": \"" + String(repeating: "a", count: 600) + "\"\n}"
        cell.contentView.addSubview(blob)

        guard let resolved = cell.userpilotResolvedCellText(touchedView: blob) else {
            return XCTFail("Expected bounded text, got nil")
        }

        XCTAssertLessThanOrEqual(resolved.count, Constants.AutoCapture.maxTargetTextLength)
        XCTAssertFalse(resolved.contains("\n"), "Multi-line blobs must be collapsed to one line")
        XCTAssertTrue(resolved.hasSuffix("…"), "Bounded text is marked as truncated, got \(resolved)")
    }

    func testCellText_forHiddenLabel_skipsHiddenText() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let hidden = UILabel()
        hidden.text = "No properties"
        hidden.isHidden = true
        let visible = UILabel()
        visible.text = "Identify"
        cell.contentView.addSubview(hidden)
        cell.contentView.addSubview(visible)

        XCTAssertEqual(cell.userpilotResolvedCellText(touchedView: cell.contentView), "Identify")
    }

    func testCellText_forRedactedLabel_skipsRedactedTextAndUsesNextLabel() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let secret = UILabel()
        secret.text = "4242 4242 4242 4242"
        secret.userpilotRedactText = true
        let visible = UILabel()
        visible.text = "Payment method"
        cell.contentView.addSubview(secret)
        cell.contentView.addSubview(visible)

        XCTAssertEqual(cell.userpilotResolvedCellText(touchedView: cell.contentView), "Payment method")
    }

    func testCellText_forRedactedCell_usesRedactionPlaceholder() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Events log"
        cell.userpilotRedactText = true

        XCTAssertEqual(
            cell.userpilotResolvedCellText(touchedView: cell.contentView),
            Constants.AutoCapture.reductText
        )
    }

    /// The row title is read off `textLabel`, a CHILD of the cell, but the policy used to be
    /// evaluated on the cell - whose responder chain walks UPWARD and never sees that label.
    /// Marking the title itself therefore published it verbatim.
    func testCellText_forRedactedTitleLabel_usesRedactionPlaceholder() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "j.doe@example.com"
        cell.textLabel?.userpilotRedactText = true

        XCTAssertEqual(
            cell.userpilotResolvedCellText(touchedView: cell.contentView),
            Constants.AutoCapture.reductText,
            "A redacted title label must never publish its text as target_text"
        )
    }

    /// Redaction on the detail label must not suppress a title the host left readable.
    func testCellText_forRedactedDetailLabelOnly_stillPublishesTheTitle() {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = "Email"
        cell.detailTextLabel?.text = "j.doe@example.com"
        cell.detailTextLabel?.userpilotRedactText = true

        XCTAssertEqual(
            cell.userpilotResolvedCellText(touchedView: cell.detailTextLabel),
            "Email"
        )
    }

    func testCellText_forCellWithoutAnyLabel_fallsBackToTouchedView() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let textView = UITextView()
        textView.text = "Terms and conditions"
        cell.contentView.addSubview(textView)

        XCTAssertEqual(cell.userpilotResolvedCellText(touchedView: textView), "Terms and conditions")
    }

    // MARK: - Table section header / footer

    func testHeaderText_forTouchedOnNonTextSubview_usesHeaderTitle() {
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        header.textLabel?.text = "Recent events"
        let icon = UIImageView()
        header.contentView.addSubview(icon)

        XCTAssertEqual(header.userpilotResolvedHeaderFooterText(touchedView: icon), "Recent events")
    }

    func testHeaderText_forCustomHeaderTouchedOnSubtitle_usesHeaderTitle() {
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        let title = UILabel()
        title.text = "Recent events"
        let subtitle = UILabel()
        subtitle.text = "Tap a row to inspect the full payload JSON that was sent"
        header.contentView.addSubview(title)
        header.contentView.addSubview(subtitle)

        XCTAssertEqual(header.userpilotResolvedHeaderFooterText(touchedView: subtitle), "Recent events")
    }

    func testHeaderText_forRedactedHeader_usesRedactionPlaceholder() {
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        let title = UILabel()
        title.text = "Recent events"
        header.contentView.addSubview(title)
        header.userpilotRedactText = true

        XCTAssertEqual(
            header.userpilotResolvedHeaderFooterText(touchedView: title),
            Constants.AutoCapture.reductText
        )
    }

    /// Same child-vs-container mismatch as the cell title.
    func testHeaderText_forRedactedTitleLabel_usesRedactionPlaceholder() {
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        header.textLabel?.text = "j.doe@example.com"
        header.textLabel?.userpilotRedactText = true

        XCTAssertEqual(
            header.userpilotResolvedHeaderFooterText(touchedView: header.contentView),
            Constants.AutoCapture.reductText,
            "A redacted header title label must never publish its text as target_text"
        )
    }

    // MARK: - Collection supplementary view

    func testSupplementaryText_forTouchedOnCountLabel_usesHeaderTitle() {
        let header = UICollectionReusableView(frame: .zero)
        let title = UILabel()
        title.text = "Screens"
        let count = UILabel()
        count.text = "12"
        header.addSubview(title)
        header.addSubview(count)

        XCTAssertEqual(header.userpilotResolvedSupplementaryText(touchedView: count), "Screens")
    }

    func testSupplementaryText_forViewWithoutText_fallsBackToTouchedView() {
        let header = UICollectionReusableView(frame: .zero)
        let textView = UITextView()
        textView.text = "Section notes"

        XCTAssertEqual(header.userpilotResolvedSupplementaryText(touchedView: textView), "Section notes")
    }

    // MARK: - Collection view cell

    func testItemText_forCustomItemTouchedOnJSONPreview_usesRowTitleNotTheBlob() {
        let cell = UICollectionViewCell(frame: .zero)
        let title = UILabel()
        title.text = "Screen"
        let blob = UILabel()
        blob.text = "{\n  \"screen_name\": \"Userpilot\"\n}"
        cell.contentView.addSubview(title)
        cell.contentView.addSubview(blob)

        XCTAssertEqual(cell.userpilotResolvedCellText(touchedView: blob), "Screen")
    }

    func testItemText_forRedactedItem_usesRedactionPlaceholder() {
        let cell = UICollectionViewCell(frame: .zero)
        let title = UILabel()
        title.text = "Screen"
        cell.contentView.addSubview(title)
        cell.userpilotRedactText = true

        XCTAssertEqual(
            cell.userpilotResolvedCellText(touchedView: title),
            Constants.AutoCapture.reductText
        )
    }
}
