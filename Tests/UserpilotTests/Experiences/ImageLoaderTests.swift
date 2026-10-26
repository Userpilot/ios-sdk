//
//  ImageLoaderTests.swift
//  Userpilot SDK
//
//  The closure-based loader: placeholder then final image on main, a synchronous cache, GIF frames.
//

import ImageIO
import MobileCoreServices
import XCTest
@testable import Userpilot

final class ImageLoaderTests: XCTestCase {
    private var userpilot: MockUserpilot!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "IMG-\(UUID().uuidString)").defaultInstance(false))
        URLProtocol.registerClass(URLProtocolStub.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        URLProtocolStub.reset()
        userpilot = nil
        super.tearDown()
    }

    func testPlaceholderArrivesBeforeTheFinalImageAndBothOnMain() throws {
        let url = try stub(png(width: 240, height: 120), mime: "image/png")
        let loader = ImageLoader(container: userpilot.container)
        var deliveries: [Bool] = []
        let final = expectation(description: "final image")
        loader.loadImage(url: url, blurHash: "U3Qlh0~q%2~W00VsjZVs00icM{N]00V@o1V@",
                         size: CGSize(width: 240, height: 120)) { image, isFinal in
            XCTAssertTrue(Thread.isMainThread)
            deliveries.append(isFinal)
            if isFinal {
                XCTAssertEqual(image.size, CGSize(width: 240, height: 120))
                final.fulfill()
            }
        }
        wait(for: [final], timeout: 5)
        XCTAssertEqual(deliveries, [false, true])
    }

    func testCachedImageIsReadySynchronouslyAndSkipsThePlaceholder() throws {
        let url = try stub(png(width: 240, height: 120), mime: "image/png")
        let loader = ImageLoader(container: userpilot.container)
        XCTAssertNil(loader.cachedImage(url: url, size: CGSize(width: 240, height: 120)))
        let first = expectation(description: "first load")
        loader.loadImage(url: url, blurHash: nil, size: CGSize(width: 240, height: 120)) { _, isFinal in
            if isFinal { first.fulfill() }
        }
        wait(for: [first], timeout: 5)
        XCTAssertNotNil(loader.cachedImage(url: url, size: CGSize(width: 240, height: 120)))
        var deliveries: [Bool] = []
        let second = expectation(description: "cached load")
        loader.loadImage(url: url, blurHash: "U3Qlh0~q%2~W00VsjZVs00icM{N]00V@o1V@",
                         size: CGSize(width: 240, height: 120)) { _, isFinal in
            deliveries.append(isFinal)
            second.fulfill()
        }
        wait(for: [second], timeout: 5)
        XCTAssertEqual(deliveries, [true])
    }

    /// The cache serves an image only to boxes it covers, so a later, larger use of the same URL isn't upscaled.
    func testCachedImageIsReusedOnlyForBoxesItCovers() throws {
        let url = try stub(png(width: 2000, height: 1000), mime: "image/png")
        let loader = ImageLoader(container: userpilot.container)
        let small = CGSize(width: 100, height: 50)
        let large = CGSize(width: 400, height: 200)
        let first = expectation(description: "small load")
        loader.loadImage(url: url, blurHash: nil, size: small) { _, isFinal in if isFinal { first.fulfill() } }
        wait(for: [first], timeout: 5)
        XCTAssertNotNil(loader.cachedImage(url: url, size: small))
        XCTAssertNil(loader.cachedImage(url: url, size: large), "A 100-point decode can't serve a 400-point box")
        var width: CGFloat = 0
        let second = expectation(description: "large load")
        loader.loadImage(url: url, blurHash: nil, size: large) { image, isFinal in
            guard isFinal else { return }
            width = image.size.width
            second.fulfill()
        }
        wait(for: [second], timeout: 5)
        XCTAssertGreaterThanOrEqual(width, 399)
        XCTAssertNotNil(loader.cachedImage(url: url, size: small), "The larger decode serves smaller boxes")
    }

    func testGIFDeliversAnAnimatedImageWithItsFrames() throws {
        let url = try stub(gif(frames: 3), mime: "image/gif")
        let loader = ImageLoader(container: userpilot.container)
        let final = expectation(description: "gif")
        var frames = 0
        loader.loadImage(url: url, blurHash: nil, size: CGSize(width: 100, height: 50)) { image, isFinal in
            guard isFinal else { return }
            frames = image.images?.count ?? 0
            final.fulfill()
        }
        wait(for: [final], timeout: 5)
        XCTAssertEqual(frames, 3)
    }
}

// MARK: - Cancellation

extension ImageLoaderTests {
    func testCancellingBeforeTheDownloadStartsDeliversNothing() throws {
        let url = try stub(png(width: 240, height: 120), mime: "image/png")
        let loader = ImageLoader(container: userpilot.container)
        let delivered = expectation(description: "nothing is delivered")
        delivered.isInverted = true
        let task = loader.loadImage(url: url, blurHash: "U3Qlh0~q%2~W00VsjZVs00icM{N]00V@o1V@",
                                    size: CGSize(width: 240, height: 120)) { _, _ in delivered.fulfill() }
        task.cancel()
        wait(for: [delivered], timeout: 1)
        XCTAssertNil(loader.cachedImage(url: url, size: CGSize(width: 240, height: 120)))
    }

    func testCancellingStopsAnInFlightDownload() throws {
        let url = try stub(png(width: 240, height: 120), mime: "image/png")
        URLProtocolStub.responseDelay = 0.6
        let loader = ImageLoader(container: userpilot.container)
        let delivered = expectation(description: "no final image")
        delivered.isInverted = true
        let task = loader.loadImage(url: url, blurHash: nil, size: CGSize(width: 240, height: 120)) { _, isFinal in
            if isFinal { delivered.fulfill() }
        }
        // Give the request time to reach the network, then cancel it mid-download.
        let inFlight = expectation(description: "request in flight")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { inFlight.fulfill() }
        wait(for: [inFlight], timeout: 1)
        task.cancel()
        wait(for: [delivered], timeout: 1)
        XCTAssertEqual(URLProtocolStub.stoppedCount, 1, "The URLSession request itself was cancelled.")
        XCTAssertNil(loader.cachedImage(url: url, size: CGSize(width: 240, height: 120)))
    }
}

private extension ImageLoaderTests {
    func stub(_ data: Data, mime: String) throws -> String {
        let url = try XCTUnwrap(URL(string: "https://image-fixture.invalid/\(UUID().uuidString)"))
        URLProtocolStub.response = (data, URLResponse(
            url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil), nil)
        return url.absoluteString
    }

    func png(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func gif(frames: Int) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, kUTTypeGIF, frames, nil))
        for index in 0..<frames {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let frame = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50), format: format).image { context in
                UIColor(hue: CGFloat(index) / CGFloat(frames), saturation: 1, brightness: 1, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
            }
            let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary
            CGImageDestinationAddImage(destination, try XCTUnwrap(frame.cgImage), delay)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
