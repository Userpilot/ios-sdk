//
//  CarouselGestureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises real touch routing across the complete onboarding page and its vertical scroll.
//

import XCTest

final class CarouselGestureTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-carousel-fixture"]
        app.launch()
        assertPage(1)
    }

    override func tearDown() {
        app.terminate()
        app = nil
        super.tearDown()
    }

    func testHeaderFooterAndEmptySpaceSwipeWholePagesAndLongContentScrolls() {
        drag(app, from: CGVector(dx: 0.8, dy: 0.12), to: CGVector(dx: 0.2, dy: 0.12))
        assertPage(2)
        screenshot("carousel-page-2-after-header-swipe")

        drag(app.buttons["Next page 2"], from: CGVector(dx: 0.8, dy: 0.5), to: CGVector(dx: 0.2, dy: 0.5))
        assertPage(3)
        let end = app.staticTexts["End of long page"]
        XCTAssertFalse(end.isHittable)
        for _ in 0..<10 where !end.isHittable {
            drag(app, from: CGVector(dx: 0.5, dy: 0.75), to: CGVector(dx: 0.5, dy: 0.25))
        }
        XCTAssertTrue(end.isHittable, "Long page content must remain vertically reachable")
        XCTAssertTrue(app.buttons["Next page 3"].isHittable, "Action remains usable after scrolling")
        screenshot("carousel-long-page-after-vertical-scroll")

        drag(app, from: CGVector(dx: 0.2, dy: 0.5), to: CGVector(dx: 0.8, dy: 0.5))
        assertPage(2)
        drag(app, from: CGVector(dx: 0.2, dy: 0.55), to: CGVector(dx: 0.8, dy: 0.55))
        assertPage(1)
        screenshot("carousel-page-1-after-empty-space-swipe")
    }

    func testActionTapStillAdvancesThePage() {
        app.buttons["Next page 1"].tap()
        assertPage(2)
    }

    private func assertPage(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let visible = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["Next page \(index)"])
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 10), .completed, file: file, line: line)
    }

    private func drag(_ element: XCUIElement, from start: CGVector, to end: CGVector) {
        element.coordinate(withNormalizedOffset: start).press(
            forDuration: 0.05, thenDragTo: element.coordinate(withNormalizedOffset: end))
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
