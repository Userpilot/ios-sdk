//
//  AutoCapturerTests.swift
//  UserpilotTests
//
//  Created by OpenAI Codex on 13/04/2026.
//

import XCTest
@testable import Userpilot

final class AutoCapturerTests: XCTestCase {

    func testScreenEventIdentity_usesLogicalScreenNameForSwiftUI() {
        let userpilot = MockUserpilot(
            config: Userpilot.Config(token: "AUTOCAPTURE-SWIFTUI-\(UUID().uuidString)")
                .appFramework(.SwiftUI)
                .defaultInstance(false)
        )
        let autoCapturer = AutoCaptureCoordinater(container: userpilot.container)
        let expectation = expectation(description: "SwiftUI screen event published")
        var trackedEvent: Event?
        userpilot.analyticsPublisher.onPublish = { event in
            trackedEvent = event
            expectation.fulfill()
        }
        let payload = ScreenTrackingPayload(
            currentScreen: "HomeScreen",
            screenClass: "NavigationStackHostingController<AnyView>",
            screenType: "UIViewController",
            navigationTitle: "Test Title here",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )

        autoCapturer.trackScreen(payload)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(trackedEvent?.screenTitle, "HomeScreen")
    }

    func testScreenEventIdentity_keepsClassNameForUIKit() {
        let userpilot = MockUserpilot(
            config: Userpilot.Config(token: "AUTOCAPTURE-UIKIT-\(UUID().uuidString)")
                .appFramework(.UIKit)
                .defaultInstance(false)
        )
        let autoCapturer = AutoCaptureCoordinater(container: userpilot.container)
        var trackedEvent: Event?
        userpilot.analyticsPublisher.onPublish = { trackedEvent = $0 }
        let payload = ScreenTrackingPayload(
            currentScreen: "HomeScreen",
            screenClass: "HomeViewController",
            screenType: "UIViewController",
            navigationTitle: "Home",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )

        autoCapturer.trackScreen(payload)

        XCTAssertEqual(trackedEvent?.screenTitle, "HomeViewController")
    }
}
