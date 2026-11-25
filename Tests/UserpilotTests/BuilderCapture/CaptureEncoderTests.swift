//
//  CaptureEncoderTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers in-memory PNG and capture.json encoding and the upload size limits.
//

import XCTest
@testable import Userpilot

final class CaptureEncoderTests: XCTestCase {

    func testPrepareUploadEncodesThePNGAndDocumentInMemory() throws {
        let fixture = CaptureFixture.make(captureID: "cap-encode")
        let prepared = expectation(description: "upload prepared")
        var result: Result<CaptureUpload, CaptureEncodingError>?

        CaptureEncoder().prepareUpload(document: fixture.document, screenshot: fixture.image) {
            result = $0
            prepared.fulfill()
        }
        wait(for: [prepared], timeout: 2)

        let upload = try XCTUnwrap(try result?.get())
        XCTAssertEqual(upload.captureID, "cap-encode")
        XCTAssertNotNil(UIImage(data: upload.screenshot))
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: upload.document) as? NSDictionary)
        let expected = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.document)) as? NSDictionary)
        XCTAssertEqual(decoded, expected)
    }

    func testPartsExactlyAtTheLimitAreSent() throws {
        let upload = try CaptureEncoder.makeUpload(
            captureID: "cap-limit",
            screenshot: Data(count: Constants.BuilderCapture.Upload.maxScreenshotBytes),
            document: Data(count: Constants.BuilderCapture.Upload.maxDocumentBytes)
        ).get()

        XCTAssertEqual(upload.screenshot.count, 5_000_000)
        XCTAssertEqual(upload.document.count, 2_000_000)
    }

    func testOneByteOverEitherLimitIsTooLarge() {
        let screenshotOver = CaptureEncoder.makeUpload(
            captureID: "cap-limit", screenshot: Data(count: 5_000_001), document: Data(count: 1))
        let documentOver = CaptureEncoder.makeUpload(
            captureID: "cap-limit", screenshot: Data(count: 1), document: Data(count: 2_000_001))

        XCTAssertEqual(failure(of: screenshotOver), .tooLarge)
        XCTAssertEqual(failure(of: documentOver), .tooLarge)
    }

    private func failure(of result: Result<CaptureUpload, CaptureEncodingError>) -> CaptureEncodingError? {
        guard case let .failure(error) = result else { return nil }
        return error
    }
}

/// A one-node capture of a 4 × 4 white image on the screen event `screen`.
enum CaptureFixture {
    static func make(
        captureID: String,
        screen: Event = Event(type: .screen("Admitted")),
        tree: ElementNode? = nil
    ) -> (document: CaptureDocument, image: UIImage) {
        let bounds = CGRect(x: 0, y: 0, width: 4, height: 4)
        let image = UIGraphicsImageRenderer(size: bounds.size).image { context in
            UIColor.white.setFill()
            context.fill(bounds)
        }
        let root = tree ?? ElementNode(nodeID: "root", nativeType: "UIWindow", displayName: nil,
                                       bounds: bounds, visibleBounds: nil, selector: nil, children: [], view: nil)
        let document = CaptureDocument.make(
            captureID: captureID,
            screenshot: UserpilotScreenshot(image: image, size: bounds.size, insets: .zero),
            elementTree: root,
            screen: ScreenPayload(event: screen)
        )
        return (document, image)
    }
}
