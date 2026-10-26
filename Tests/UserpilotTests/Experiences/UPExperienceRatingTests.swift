//
//  UPExperienceRatingTests.swift
//  Userpilot SDK
//
//  The rating grid: every cell keeps the 44 pt tap target, and extra cells wrap to new rows.
//

import XCTest
@testable import Userpilot

final class UPExperienceRatingTests: XCTestCase {
    /// Content widths of a bottom sheet on 320, 375, 393 and 430 pt phones, and a dialog on iPad.
    private let widths: [CGFloat] = [248, 303, 321, 358, 600]

    func testEveryCellIsAtLeast44PointsWide() {
        for width in widths {
            for count in [3, 5, 7, 10, 11] {
                let grid = UPExperienceRating.grid(count: count, width: width, minimumCellWidth: 44)
                XCTAssertGreaterThanOrEqual(grid.cellWidth, 44, "\(count) cells across \(width) pt")
            }
        }
    }

    func testCellsFillTheRowWithoutOverflowing() {
        for width in widths {
            for count in [3, 5, 7, 10, 11] {
                let grid = UPExperienceRating.grid(count: count, width: width, minimumCellWidth: 44)
                let rowWidth = CGFloat(grid.columns) * grid.cellWidth
                    + CGFloat(grid.columns - 1) * UPExperienceRating.spacing
                XCTAssertEqual(rowWidth, width, accuracy: 0.01, "\(count) cells across \(width) pt")
            }
        }
    }

    /// Eleven NPS cells take three rows on a 375 pt phone, two on wider ones.
    func testNPSWrapsToMoreRowsOnNarrowPhones() {
        let narrow = UPExperienceRating.grid(count: 11, width: 303, minimumCellWidth: 44)
        XCTAssertEqual((11 + narrow.columns - 1) / narrow.columns, 3)
        let wide = UPExperienceRating.grid(count: 11, width: 358, minimumCellWidth: 44)
        XCTAssertEqual((11 + wide.columns - 1) / wide.columns, 2)
    }

    /// A container narrower than one cell still gets one full-width cell, never zero columns.
    func testATinyWidthStillShowsOneCellPerRow() {
        let grid = UPExperienceRating.grid(count: 11, width: 30, minimumCellWidth: 44)
        XCTAssertEqual(grid.columns, 1)
        XCTAssertEqual(grid.cellWidth, 30, accuracy: 0.01)
    }
}
