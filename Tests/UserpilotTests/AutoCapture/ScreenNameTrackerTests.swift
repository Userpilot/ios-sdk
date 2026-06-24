//
//  ScreenNameTrackerTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ScreenNameTrackerTests: XCTestCase {

    func testUpdateGetBuildAndResetScreenPayload() {
        let userpilot = MockUserpilot(
            config: Userpilot.Config(token: "SCREEN-TRACKER-\(UUID().uuidString)").defaultInstance(false)
        )
        let tracker = ScreenNameTracker(container: userpilot.container)
        let payload = ScreenTrackingPayload(
            currentScreen: "Home",
            screenClass: "HomeViewController",
            screenType: "UIViewController",
            navigationTitle: "Dashboard",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )

        tracker.updateScreen(with: payload)

        XCTAssertEqual(tracker.getCurrentPayload(), payload)
        XCTAssertEqual(tracker.buildScreenDictionary()[AutoCaptureConstants.screenName] as? String, "Home")
        XCTAssertEqual(
            tracker.buildScreenDictionaryForEvent()[AutoCaptureConstants.screenTitle],
            "HomeViewController"
        )
        XCTAssertEqual(
            tracker.buildScreenDictionaryForEvent()[AutoCaptureConstants.navigationTitle],
            "Dashboard"
        )

        tracker.reset()

        XCTAssertNil(tracker.getCurrentPayload())
        XCTAssertTrue(tracker.buildScreenDictionary().isEmpty)
        XCTAssertTrue(tracker.buildScreenDictionaryForEvent().isEmpty)
    }

    func testBuildScreenDictionaryForEventOmitsEmptyNavigationTitle() {
        let userpilot = MockUserpilot(
            config: Userpilot.Config(token: "SCREEN-TRACKER-\(UUID().uuidString)").defaultInstance(false)
        )
        let tracker = ScreenNameTracker(container: userpilot.container)
        let payload = ScreenTrackingPayload(
            currentScreen: "Home",
            screenClass: "HomeViewController",
            screenType: "UIViewController",
            navigationTitle: "",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )

        tracker.updateScreen(with: payload)

        let eventDict = tracker.buildScreenDictionaryForEvent()
        XCTAssertEqual(eventDict[AutoCaptureConstants.screenTitle], "HomeViewController")
        XCTAssertNil(eventDict[AutoCaptureConstants.navigationTitle])
    }
}
