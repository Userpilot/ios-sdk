//
//  ColorExtensionsTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ColorExtensionsTests: XCTestCase {

    func testStringHexColorParsesRGBAndAlpha() {
        assertColor("#33669980".color, red: 0x33, green: 0x66, blue: 0x99, alpha: 0.50, accuracy: 0.01)
        assertColor("336699".color, red: 0x33, green: 0x66, blue: 0x99)
    }

    func testStringHexColorFallsBackToBlackForInvalidInput() {
        assertColor("".color, red: 0, green: 0, blue: 0)
        assertColor("bad".color, red: 0, green: 0, blue: 0)
        assertColor("#XYZXYZ".color, red: 0, green: 0, blue: 0)
    }

    func testRGBAStringParsingAndClamping() {
        assertColor("rgba(255, 128, 0, 0.25)".rgbaToColor(), red: 255, green: 128, blue: 0, alpha: 0.25)
        assertColor("rgba(300, 999, 1, 2.0)".rgbaToColor(), red: 255, green: 255, blue: 1, alpha: 1.0)
        XCTAssertEqual("rgb(255, 0, 0)".rgbaToColor(), UIColor.clear)
        XCTAssertEqual("not-rgba".rgbaToColor(), UIColor.clear)
    }

    func testColorStringTransformations() {
        XCTAssertEqual("#FFFFFF".invertColor(), "#000000")
        XCTAssertEqual("#000000".invertColor(), "#FFFFFF")
        XCTAssertEqual("#123456".invertColor(blackWhite: false), "#EDCBA9")
        XCTAssertEqual("#03F".invertColor(), "0033FF")
        XCTAssertEqual("rgb(10, 20, 30)".updateRgbaOpacity(opacity: "0.4"), "rgba(10, 20, 30, 0.4)")
        XCTAssertEqual("rgba(10, 20, 30, 1)".updateRgbaOpacity(opacity: "0.4"), "rgba(10, 20, 30, 0.4)")
        XCTAssertNil("#FFFFFF".updateRgbaOpacity(opacity: "0.4"))
        XCTAssertNil("hsl(120, 100%, 50%)".updateRgbaOpacity(opacity: "0.4"))
        XCTAssertEqual("#FF0000".hexToRgb(), "rgb(255, 0, 0)")
        XCTAssertEqual("00FF00".hexToRgb(), "rgb(0, 255, 0)")
        XCTAssertEqual("#0000FF".hexToRgb(), "rgb(0, 0, 255)")
        XCTAssertEqual("#336699".hexToRgb(), "rgb(51, 102, 153)")
    }

    func testUIColorHexInitializersAndHelpers() throws {
        assertColor(UIColor(hex: "#336699"), red: 0x33, green: 0x66, blue: 0x99)
        assertColor(
            try XCTUnwrap(UIColor(hexString: "#80336699")),
            red: 0x33,
            green: 0x66,
            blue: 0x99,
            alpha: 0.50,
            accuracy: 0.01
        )
        XCTAssertNil(UIColor(hexString: "#12345"))
        XCTAssertTrue(UIColor.white.isLightColor())
        XCTAssertFalse(UIColor.black.isLightColor())

        var alpha: CGFloat = 0
        UIColor.red.withOpacity(0.35).getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.35, accuracy: 0.01)
        XCTAssertEqual(
            UIColor(
                red: CGFloat(0x33) / 255.0,
                green: CGFloat(0x66) / 255.0,
                blue: CGFloat(0x99) / 255.0,
                alpha: 1
            ).toHexStringWithAlpha(alpha: 0.5),
            "#7F336699"
        )
    }

    private func assertColor(
        _ color: UIColor,
        red expectedRed: Int,
        green expectedGreen: Int,
        blue expectedBlue: Int,
        alpha expectedAlpha: CGFloat = 1,
        accuracy: CGFloat = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha), file: file, line: line)
        XCTAssertEqual(red, CGFloat(expectedRed) / 255.0, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(green, CGFloat(expectedGreen) / 255.0, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(blue, CGFloat(expectedBlue) / 255.0, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(alpha, expectedAlpha, accuracy: accuracy, file: file, line: line)
    }
}
