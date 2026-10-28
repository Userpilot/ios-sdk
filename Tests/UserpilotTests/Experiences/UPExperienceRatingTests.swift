//
//  UPExperienceRatingTests.swift
//  Userpilot SDK
//
//  The rating grid: one row up to five cells, otherwise two rows, with the cells filling the width.
//

import XCTest
@testable import Userpilot

final class UPExperienceRatingTests: XCTestCase {
    /// Content widths of a bottom sheet on 320, 375, 393 and 430 pt phones, and a dialog on iPad.
    private let widths: [CGFloat] = [248, 303, 321, 358, 600]

    func testUpToFiveCellsStayOnOneRow() {
        for count in 1...5 {
            XCTAssertEqual(UPExperienceRating.grid(count: count, width: 321).columns, count)
        }
    }

    /// Longer scales split over two rows with the fuller one on top, as Android does: NPS is six over five.
    func testLongerScalesSplitOverTwoRows() {
        XCTAssertEqual(UPExperienceRating.grid(count: 7, width: 321).columns, 4)
        XCTAssertEqual(UPExperienceRating.grid(count: 10, width: 321).columns, 5)
        XCTAssertEqual(UPExperienceRating.grid(count: 11, width: 321).columns, 6)
    }

    /// The scale lines up with the text on both sides at every width.
    func testCellsFillTheRowWithoutOverflowing() {
        for width in widths {
            for count in [3, 5, 7, 10, 11] {
                let grid = UPExperienceRating.grid(count: count, width: width)
                let rowWidth = CGFloat(grid.columns) * grid.cellWidth
                    + CGFloat(grid.columns - 1) * UPExperienceRating.spacing
                XCTAssertEqual(rowWidth, width, accuracy: 0.01, "\(count) cells across \(width) pt")
            }
        }
    }

    /// A container narrower than its gaps still gives every cell a positive width.
    func testATinyWidthNeverGivesANegativeCell() {
        XCTAssertGreaterThan(UPExperienceRating.grid(count: 11, width: 30).cellWidth, 0)
    }
}
