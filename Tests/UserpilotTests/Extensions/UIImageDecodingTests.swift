//
//  UIImageDecodingTests.swift
//  Userpilot SDK
//
//  Decoding keeps each image's own proportions and never decodes more pixels than its box needs.
//

import ImageIO
import MobileCoreServices
import XCTest
@testable import Userpilot

final class UIImageDecodingTests: XCTestCase {
    private let scale = UIGraphicsImageRendererFormat.default().scale

    func testDefaultSquareBoxKeepsTheSourceAspectRatio() throws {
        let image = try XCTUnwrap(
            UIImage.decoded(from: png(width: 200, height: 100), size: CGSize(width: 300, height: 300)))
        XCTAssertEqual(image.size.width / image.size.height, 2, accuracy: 0.02)
    }

    func testLargeSourceIsDownscaledToItsBoxAtTheSourceAspect() throws {
        let image = try XCTUnwrap(
            UIImage.decoded(from: png(width: 2000, height: 1000), size: CGSize(width: 240, height: 120)))
        XCTAssertLessThanOrEqual(image.size.width, 240 + 1)
        XCTAssertLessThanOrEqual(image.size.height, 120 + 1)
        XCTAssertEqual(image.size.width / image.size.height, 2, accuracy: 0.02)
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertLessThanOrEqual(CGFloat(pixels.width), 240 * scale + 1)
    }

    func testMismatchedFixedBoxCoversTheBoxWithoutDistortion() throws {
        let image = try XCTUnwrap(
            UIImage.decoded(from: png(width: 2000, height: 1000), size: CGSize(width: 100, height: 100)))
        XCTAssertEqual(image.size.width / image.size.height, 2, accuracy: 0.02)
        XCTAssertGreaterThanOrEqual(image.size.height, 100 - 1, "Covers the box so fill and fit stay sharp.")
    }

    func testAnimatedFramesAreDownscaledWithSameCountOrderAndDuration() throws {
        let colors: [UIColor] = [.red, .green, .blue]
        let data = try gif(width: 1000, height: 500, colors: colors, delay: 0.2)
        let image = try XCTUnwrap(UIImage.decoded(from: data, size: CGSize(width: 200, height: 100)))
        let frames = try XCTUnwrap(image.images)
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(image.duration, 0.6, accuracy: 0.01)
        for (frame, color) in zip(frames, colors) {
            XCTAssertLessThanOrEqual(frame.size.width, 200 + 1)
            XCTAssertLessThanOrEqual(frame.size.height, 100 + 1)
            XCTAssertEqual(frame.size.width / frame.size.height, 2, accuracy: 0.02)
            try assertCenter(of: frame, is: color)
        }
    }

    func testRotatedJPEGKeepsItsOrientation() throws {
        // Raw pixels: red left half, blue right half. EXIF 6 rotates them 90° clockwise for display.
        let data = try jpeg(width: 2000, height: 1000, orientation: 6)
        let image = try XCTUnwrap(UIImage.decoded(from: data, size: CGSize(width: 100, height: 200)))
        XCTAssertGreaterThan(image.size.height, image.size.width)
        try assertColor(of: image, at: CGPoint(x: 0.5, y: 0.25), is: .red)
        try assertColor(of: image, at: CGPoint(x: 0.5, y: 0.75), is: .blue)
    }

    func testSmallSourceKeepsTodaysBoxSize() throws {
        let image = try XCTUnwrap(
            UIImage.decoded(from: png(width: 240, height: 120), size: CGSize(width: 240, height: 120)))
        XCTAssertEqual(image.size.width, 240, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 120, accuracy: 0.5)
    }
}

private extension UIImageDecodingTests {
    func png(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func cgImage(width: Int, height: Int, fill: (CGContext) -> Void) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        fill(context)
        return try XCTUnwrap(context.makeImage())
    }

    func gif(width: Int, height: Int, colors: [UIColor], delay: Double) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, kUTTypeGIF, colors.count, nil))
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
        for color in colors {
            let frame = try cgImage(width: width, height: height) { context in
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            CGImageDestinationAddImage(destination, frame, frameProperties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func jpeg(width: Int, height: Int, orientation: Int) throws -> Data {
        let image = try cgImage(width: width, height: height) { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func assertCenter(of image: UIImage, is expected: UIColor,
                      file: StaticString = #filePath, line: UInt = #line) throws {
        try assertColor(of: image, at: CGPoint(x: 0.5, y: 0.5), is: expected, file: file, line: line)
    }

    /// Samples the image as displayed (orientation applied) at a unit point.
    func assertColor(of image: UIImage, at point: CGPoint, is expected: UIColor,
                     file: StaticString = #filePath, line: UInt = #line) throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let sample = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(at: CGPoint(x: -image.size.width * point.x, y: -image.size.height * point.y))
        }
        let pixel = try XCTUnwrap(sample.cgImage?.dataProvider?.data as Data?)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let info = try XCTUnwrap(sample.cgImage?.bitmapInfo)
        let bgra = info.contains(.byteOrder32Little)
        let channels = bgra ? (pixel[2], pixel[1], pixel[0]) : (pixel[0], pixel[1], pixel[2])
        XCTAssertEqual(CGFloat(channels.0) / 255, red, accuracy: 0.2, "red", file: file, line: line)
        XCTAssertEqual(CGFloat(channels.1) / 255, green, accuracy: 0.2, "green", file: file, line: line)
        XCTAssertEqual(CGFloat(channels.2) / 255, blue, accuracy: 0.2, "blue", file: file, line: line)
    }
}
