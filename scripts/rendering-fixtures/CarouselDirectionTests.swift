//
//  CarouselDirectionTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 25/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Real swipes for every app/content direction pair: content direction alone decides the forward swipe.
//

import XCTest

final class CarouselDirectionTests: XCTestCase {
    private static let rtlAppArguments = ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES",
                                          "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]

    func testLTRContentInLTRAppAdvancesOnLeftwardSwipe() {
        assertForward(appRTL: false, locale: "en", rightward: false)
    }

    func testRTLContentInLTRAppAdvancesOnRightwardSwipe() {
        assertForward(appRTL: false, locale: "ar", rightward: true)
    }

    func testLTRContentInRTLAppAdvancesOnLeftwardSwipe() {
        assertForward(appRTL: true, locale: "en", rightward: false)
    }

    func testRTLContentInRTLAppAdvancesOnRightwardSwipe() {
        assertForward(appRTL: true, locale: "ar", rightward: true)
    }

    /// From the first page, the backward swipe has no page to show, so whichever swipe advances is the forward one.
    private func assertForward(appRTL: Bool, locale: String, rightward: Bool,
                               file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        app.launchArguments = ["-carousel-fixture"] + (appRTL ? Self.rtlAppArguments : [])
        app.launchEnvironment["FIXTURE_LOCALE"] = locale
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(isShowing(app, page: 1, timeout: 10), "First page never appeared", file: file, line: line)

        drag(app, from: 0.8, to: 0.2)
        var observed = isShowing(app, page: 2, timeout: 3) ? "leftward" : "neither"
        if observed == "neither" {
            drag(app, from: 0.2, to: 0.8)
            if isShowing(app, page: 2, timeout: 3) { observed = "rightward" }
        }
        XCTAssertEqual(observed, rightward ? "rightward" : "leftward",
                       "Forward swipe for \(locale) content in an \(appRTL ? "RTL" : "LTR") app",
                       file: file, line: line)
    }

    private func isShowing(_ app: XCUIApplication, page: Int, timeout: TimeInterval) -> Bool {
        let visible = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["Next page \(page)"])
        return XCTWaiter.wait(for: [visible], timeout: timeout) == .completed
    }

    private func drag(_ app: XCUIApplication, from startX: CGFloat, to endX: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5)).press(
            forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.5)))
    }
}
