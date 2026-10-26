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

    func testAnythingElseIsThreeHundredSquareShrunkToTheWidth() {
        for (width, height) in [("auto", "100"), ("50%", "50%"), ("120.5", "80"), (nil, nil)] as [(String?, String?)] {
            let line = image(width: width, height: height, actual: (600, 300))
            XCTAssertEqual(line.imageSize(fitting: 335), CGSize(width: 300, height: 300), "\(width ?? "nil")")
            XCTAssertEqual(line.imageSize(fitting: 250), CGSize(width: 250, height: 250), "\(width ?? "nil")")
        }
    }

    func testDialogAndSheetWidthsUseTheirOwnWidthNotTheScreen() {
        let line = image(width: "auto", height: "auto", actual: (400, 200))
        XCTAssertEqual(line.imageSize(fitting: 311), CGSize(width: 311, height: 155.5))
        XCTAssertEqual(line.imageSize(fitting: 358), CGSize(width: 358, height: 179))
    }
}

private extension LineImageSizeTests {
    func image(width: String?, height: String?, actual: (Int, Int)) -> Line {
        var style: [String: Any] = ["object_fit": "contain"]
        if let width { style["width"] = width }
        if let height { style["height"] = height }
        let attrs: [String: Any] = [
            "__type__": "image", "src": "https://example.com/a.png",
            "actual_size": ["width": actual.0, "height": actual.1],
            "style": width == nil && height == nil ? NSNull() : style
        ]
        let json: [String: Any] = ["type": "image", "attrs": attrs, "content": []]
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Line.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
