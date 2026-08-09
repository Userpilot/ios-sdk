//
//  ImageSizingParityTests.swift
//  UserpilotTests
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  An image has to resolve to the same size and aspect on iOS as on Android, so the same experience
//  renders identically on both. These pin the rules ported from the Android SDK's `UPImageView`.
//
//  The behaviour that changed: `getImageSize` used to cap the requested size against
//  `screenWidth - contentMargin * 2` — an assumption that every host was the carousel's full-bleed
//  content area. `SlideOutContainerView` puts the same image inside an inset card, so the cap
//  over-estimated the room and a wide image overflowed. The size is now stated uncapped and fitted to
//  the container's real width by the view, which is what Android does in `onMeasure`.
//

import XCTest
@testable import Userpilot

final class ImageSizingParityTests: XCTestCase {

    // MARK: - Fixtures

    private func makeLine(
        styleWidth: String?,
        styleHeight: String?,
        actualWidth: Int?,
        actualHeight: Int?
    ) throws -> Line {
        var attrs: [String: Any] = [:]
        if styleWidth != nil || styleHeight != nil {
            var style: [String: Any] = [:]
            style["width"] = styleWidth
            style["height"] = styleHeight
            attrs["style"] = style
        }
        if actualWidth != nil || actualHeight != nil {
            var actual: [String: Any] = [:]
            actual["width"] = actualWidth
            actual["height"] = actualHeight
            attrs["actual_size"] = actual
        }
        let payload: [String: Any] = ["type": "image", "attrs": attrs]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Line.self, from: data)
    }

    // MARK: - The requested size, uncapped

    func testAutoUsesTheImagesOwnSize() throws {
        let line = try makeLine(
            styleWidth: "auto", styleHeight: "auto", actualWidth: 240, actualHeight: 120)

        XCTAssertEqual(getImageSize(for: line), CGSize(width: 240, height: 120))
    }

    func testAnExplicitBoxIsUsedVerbatim() throws {
        let line = try makeLine(
            styleWidth: "180px", styleHeight: "90px", actualWidth: 900, actualHeight: 900)

        XCTAssertEqual(getImageSize(for: line), CGSize(width: 180, height: 90))
    }

    func testAnUnparseableSizeFallsBackToTheDefaultSquare() throws {
        let line = try makeLine(
            styleWidth: "50%", styleHeight: "auto", actualWidth: nil, actualHeight: nil)

        let side = ThemeHandler.DefaultValues.imageSize
        XCTAssertEqual(getImageSize(for: line), CGSize(width: side, height: side))
    }

    func testTheRequestedSizeIsNotCappedToTheScreen() throws {
        // The heart of it: a size wider than any screen is reported as asked. Capping here is what
        // made the figure wrong in an inset card, because this function cannot know the container.
        let line = try makeLine(
            styleWidth: "auto", styleHeight: "auto", actualWidth: 4000, actualHeight: 2000)

        XCTAssertEqual(getImageSize(for: line).width, 4000)
    }

    // MARK: - The aspect used when shrinking

    func testTheSourceRatioIsPreferred() throws {
        // Deliberately a different shape from the requested box: shrinking follows the *source*.
        let line = try makeLine(
            styleWidth: "180px", styleHeight: "180px", actualWidth: 400, actualHeight: 100)

        XCTAssertEqual(
            sourceAspect(for: line, imageSize: CGSize(width: 180, height: 180)), 0.25, accuracy: 0.001)
    }

    func testAZeroActualWidthDoesNotDivideByZero() throws {
        // `{"width": 0}` used to be an arithmetic error; it falls back to the requested box's ratio.
        let line = try makeLine(
            styleWidth: "200px", styleHeight: "50px", actualWidth: 0, actualHeight: 300)

        XCTAssertEqual(
            sourceAspect(for: line, imageSize: CGSize(width: 200, height: 50)), 0.25, accuracy: 0.001)
    }

    func testWithNothingToGoOnTheAspectIsSquare() throws {
        let line = try makeLine(
            styleWidth: nil, styleHeight: nil, actualWidth: nil, actualHeight: nil)

        XCTAssertEqual(sourceAspect(for: line, imageSize: .zero), 1, accuracy: 0.001)
    }

    // MARK: - Fitting to the container

    /// Lays the view out inside a container of a given width, as a stack view would.
    private func layout(_ view: UPImageView, inWidth width: CGFloat) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 1000))
        host.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            view.topAnchor.constraint(equalTo: host.topAnchor)
        ])
        hosts.append(host)
        host.layoutIfNeeded()
    }

    private var hosts: [UIView] = []

    override func tearDown() {
        hosts.removeAll()
        super.tearDown()
    }

    func testAnImageThatFitsKeepsItsRequestedSize() throws {
        let line = try makeLine(
            styleWidth: "auto", styleHeight: "auto", actualWidth: 200, actualHeight: 100)
        let view = UPImageView(frame: .zero)
        view.setupView(line: line, imageLoader: MockImageLoader())

        layout(view, inWidth: 320)

        // Never enlarged to fill the container — an image narrower than its host stays narrow.
        XCTAssertEqual(view.bounds.height, 100, accuracy: 0.5)
    }

    func testAWideImageShrinksToTheContainerKeepingItsAspect() throws {
        let line = try makeLine(
            styleWidth: "auto", styleHeight: "auto", actualWidth: 800, actualHeight: 400)
        let view = UPImageView(frame: .zero)
        view.setupView(line: line, imageLoader: MockImageLoader())

        layout(view, inWidth: 300)

        // 300 wide at the source's 1:2 ratio.
        XCTAssertEqual(view.bounds.height, 150, accuracy: 0.5)
    }

    func testTheSameImageShrinksFurtherInANarrowerCard() throws {
        // The slide-out's inset card versus the carousel's full-bleed content: the identical line
        // resolves to different heights because the limit is the container, not the screen.
        let line = try makeLine(
            styleWidth: "auto", styleHeight: "auto", actualWidth: 800, actualHeight: 400)

        let wide = UPImageView(frame: .zero)
        wide.setupView(line: line, imageLoader: MockImageLoader())
        layout(wide, inWidth: 360)

        let narrow = UPImageView(frame: .zero)
        narrow.setupView(line: line, imageLoader: MockImageLoader())
        layout(narrow, inWidth: 240)

        XCTAssertEqual(wide.bounds.height, 180, accuracy: 0.5)
        XCTAssertEqual(narrow.bounds.height, 120, accuracy: 0.5)
    }

    func testShrinkingUsesTheSourceRatioNotTheRequestedBoxes() throws {
        // The case the two ratios disagree: a square box asked for, a 4:1 source. Android recomputes
        // the height from the source, so the shrunk image keeps the picture's shape.
        let line = try makeLine(
            styleWidth: "400px", styleHeight: "400px", actualWidth: 800, actualHeight: 200)
        let view = UPImageView(frame: .zero)
        view.setupView(line: line, imageLoader: MockImageLoader())

        layout(view, inWidth: 200)

        XCTAssertEqual(view.bounds.height, 50, accuracy: 0.5)
    }

    func testRebindingResizesRatherThanStackingConstraints() throws {
        // This view is rebuilt per step and `setupView` used to activate a fresh pair of constraints
        // on every call, which conflict as soon as the size differs.
        let view = UPImageView(frame: .zero)
        view.setupView(
            line: try makeLine(
                styleWidth: "auto", styleHeight: "auto", actualWidth: 200, actualHeight: 100),
            imageLoader: MockImageLoader())
        layout(view, inWidth: 320)

        view.setupView(
            line: try makeLine(
                styleWidth: "auto", styleHeight: "auto", actualWidth: 200, actualHeight: 40),
            imageLoader: MockImageLoader())
        let host = try XCTUnwrap(view.superview)
        host.setNeedsLayout()
        host.layoutIfNeeded()

        XCTAssertFalse(view.hasAmbiguousLayout)
        XCTAssertEqual(view.bounds.height, 40, accuracy: 0.5)
    }
}
