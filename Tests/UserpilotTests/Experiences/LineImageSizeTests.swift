//
//  LineImageSizeTests.swift
//  Userpilot SDK
//
//  The shared iOS/Android image size rule, applied once to the width the parent passes in.
//

import XCTest
@testable import Userpilot

final class LineImageSizeTests: XCTestCase {

    func testAutoUsesTheNaturalSizeShrunkToTheWidthAtItsAspect() {
        let line = image(width: "auto", height: "auto", actual: (301, 245))
        XCTAssertEqual(line.imageSize(fitting: 335), CGSize(width: 301, height: 245))
        let fitted = line.imageSize(fitting: 200)
        XCTAssertEqual(fitted.width, 200, accuracy: 0.01)
        XCTAssertEqual(fitted.height, 200 * 245 / 301, accuracy: 0.01)
    }

    func testNumericUsesTheAuthoredSizeWhenItFits() {
        XCTAssertEqual(image(width: "120", height: "80", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 120, height: 80))
        XCTAssertEqual(image(width: "120px", height: "80px", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 120, height: 80))
        XCTAssertEqual(image(width: "120.5", height: "80", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 120.5, height: 80))
    }

    func testNumericWiderThanTheWidthTakesTheWidthAndTheNaturalAspect() {
        let size = image(width: "600", height: "500", actual: (1200, 400)).imageSize(fitting: 335)
        XCTAssertEqual(size.width, 335, accuracy: 0.01)
        XCTAssertEqual(size.height, 335 * 400 / 1200, accuracy: 0.01)
        // Even when the natural image is narrower than the width.
        let small = image(width: "600", height: "500", actual: (200, 100)).imageSize(fitting: 335)
        XCTAssertEqual(small.width, 335, accuracy: 0.01)
        XCTAssertEqual(small.height, 167.5, accuracy: 0.01)
    }

    func testOneSideAutoKeepsTheNumericSideAndTakesTheOtherFromTheNaturalAspect() {
        XCTAssertEqual(image(width: "300", height: "auto", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 300, height: 150))
        XCTAssertEqual(image(width: "auto", height: "100px", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 200, height: 100))
        // Still shrunk to the width at that aspect.
        XCTAssertEqual(image(width: "auto", height: "300", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 335, height: 167.5))
        XCTAssertEqual(image(width: "600", height: "auto", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 335, height: 167.5))
    }

    func testAPercentageWidthIsOfTheAvailableWidthWithTheHeightAtTheNaturalAspect() {
        XCTAssertEqual(image(width: "100%", height: "auto", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 335, height: 167.5))
        XCTAssertEqual(image(width: "50%", height: "auto", actual: (600, 300)).imageSize(fitting: 300),
                       CGSize(width: 150, height: 75))
        XCTAssertEqual(image(width: "100%", height: "120", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 335, height: 120))
    }

    func testAPercentageHeightAnUnreadableSideOrNoStyleIsAuto() {
        XCTAssertEqual(image(width: "300", height: "50%", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 300, height: 150))
        XCTAssertEqual(image(width: "abc", height: "100", actual: (600, 300)).imageSize(fitting: 335),
                       CGSize(width: 200, height: 100))
        XCTAssertEqual(image(width: nil, height: nil, actual: (300, 200)).imageSize(fitting: 335),
                       CGSize(width: 300, height: 200))
    }

    func testWithoutAnActualSizeTheImageIsTakenAsThreeHundredSquare() {
        XCTAssertEqual(image(width: "auto", height: "auto", actual: nil).imageSize(fitting: 335),
                       CGSize(width: 300, height: 300))
        XCTAssertEqual(image(width: "auto", height: "auto", actual: (0, 200)).imageSize(fitting: 250),
                       CGSize(width: 250, height: 250))
        XCTAssertEqual(image(width: "100%", height: "auto", actual: nil).imageSize(fitting: 335),
                       CGSize(width: 335, height: 335))
        XCTAssertEqual(image(width: "120", height: "80", actual: nil).imageSize(fitting: 335),
                       CGSize(width: 120, height: 80))
    }

    func testDialogAndSheetWidthsUseTheirOwnWidthNotTheScreen() {
        let line = image(width: "auto", height: "auto", actual: (400, 200))
        XCTAssertEqual(line.imageSize(fitting: 311), CGSize(width: 311, height: 155.5))
        XCTAssertEqual(line.imageSize(fitting: 358), CGSize(width: 358, height: 179))
    }

    func testAContainedPictureIsCentredInItsFrameAtTheNaturalAspect() {
        let square = CGSize(width: 300, height: 300)
        XCTAssertEqual(image(width: "300", height: "300", actual: (600, 300)).pictureSize(in: square),
                       CGSize(width: 300, height: 150))
        XCTAssertEqual(image(width: "300", height: "300", actual: (900, 1200)).pictureSize(in: square),
                       CGSize(width: 225, height: 300))
        // A frame already at the natural aspect is the picture.
        XCTAssertEqual(image(width: "300", height: "auto", actual: (600, 300))
                        .pictureSize(in: CGSize(width: 300, height: 150)),
                       CGSize(width: 300, height: 150))
    }

    func testFillCoverAndAMissingActualSizeDrawThePictureOverTheWholeFrame() {
        let frame = CGSize(width: 300, height: 300)
        for fit in ["fill", "cover"] {
            let line = image(width: "300", height: "300", actual: (600, 300), fit: fit)
            XCTAssertEqual(line.pictureSize(in: frame), frame, fit)
        }
        XCTAssertEqual(image(width: "300", height: "300", actual: nil).pictureSize(in: frame), frame)
    }
}

private extension LineImageSizeTests {
    func image(width: String?, height: String?, actual: (Int, Int)?, fit: String = "contain") -> Line {
        var style: [String: Any] = ["object_fit": fit]
        if let width { style["width"] = width }
        if let height { style["height"] = height }
        let attrs: [String: Any] = [
            "__type__": "image", "src": "https://example.com/a.png",
            "actual_size": actual.map { ["width": $0.0, "height": $0.1] as Any } ?? NSNull(),
            "style": width == nil && height == nil ? NSNull() : style
        ]
        let json: [String: Any] = ["type": "image", "attrs": attrs, "content": []]
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Line.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
