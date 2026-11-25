//
//  ScreenSnapshotterTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies custom screenshot handoff and unchanged native fallback.
//

import XCTest
@testable import Userpilot

final class ScreenSnapshotterTests: XCTestCase {
    func testCustomScreenshotUsesAdmittedWindowAndLogicalScale() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 40, height: 60))
        let strategy = TestElementTargetingStrategy()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.preferredRange = .standard
        let source = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(window.bounds)
        }
        strategy.screenshot = UserpilotScreenshot(image: source, size: window.bounds.size, insets: .zero)
        let image = try XCTUnwrap(snapshotter(strategy).snapshot(of: window)).image

        XCTAssertTrue(strategy.capturedWindow === window)
        XCTAssertEqual(image.scale, 1)
        XCTAssertEqual(image.cgImage?.width, 40)
        XCTAssertEqual(image.cgImage?.height, 60)
        format.scale = 1
        let expected = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(window.bounds)
        }
        XCTAssertEqual(image.pngData(), expected.pngData())
    }

    func testNullScreenshotUsesNativeRendering() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 40, height: 60))
        let strategy = TestElementTargetingStrategy()
        let image = try XCTUnwrap(snapshotter(strategy).snapshot(of: window))
        XCTAssertEqual(image.size, window.bounds.size)
        XCTAssertTrue(strategy.capturedWindow === window)
    }

    func testCroppedWrapperScreenshotPreservesViewportInsetsAndDocument() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 40, height: 60))
        let strategy = TestElementTargetingStrategy()
        let size = CGSize(width: 40, height: 50)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 100)).image { _ in }
        let insets = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        strategy.screenshot = UserpilotScreenshot(image: image, size: size, insets: insets)
        let screenshot = try XCTUnwrap(snapshotter(strategy).snapshot(of: window))
        XCTAssertEqual(screenshot.size, size)
        XCTAssertEqual(screenshot.insets, insets)
        XCTAssertEqual(screenshot.image.cgImage?.height, 50)
        let tree = ElementNode(nodeID: "root", nativeType: "Flutter", displayName: nil, bounds: .zero,
                               visibleBounds: nil, selector: nil, children: [], view: nil)
        let document = CaptureDocument.make(captureID: "snapshot", screenshot: screenshot, elementTree: tree,
                                           screen: ScreenPayload(event: Event(type: .screen("test"))))
        XCTAssertEqual(document.viewport.height, 50)
        XCTAssertEqual(document.viewport.safeAreaInsets.top, 10)
        XCTAssertEqual(document.viewport.safeAreaInsets.bottom, 0)
        XCTAssertEqual(document.screenshot.heightPx, 50)
    }

    func testInvalidWrapperViewportIsRejected() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 40, height: 60))
        let strategy = TestElementTargetingStrategy()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { _ in }
        strategy.screenshot = UserpilotScreenshot(image: image, size: .zero, insets: .zero)
        XCTAssertNil(snapshotter(strategy).snapshot(of: window))
    }

    func testEmptyWindowDoesNotCallCustomScreenshot() {
        let strategy = TestElementTargetingStrategy()
        XCTAssertNil(snapshotter(strategy).snapshot(of: UIWindow(frame: .zero)))
        XCTAssertNil(strategy.capturedWindow)
    }

    private func snapshotter(_ strategy: UserpilotElementTargetingStrategy) -> ScreenSnapshotter {
        let container = DIContainer()
        container.register(Userpilot.Config.self, value: Userpilot.Config(token: "snapshot-test"))
        container.register(UserpilotElementTargetingStrategy.self, value: strategy)
        return ScreenSnapshotter(container: container)
    }
}
