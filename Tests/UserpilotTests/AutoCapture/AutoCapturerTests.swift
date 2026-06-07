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
            config: Userpilot.Config(token: "NX-00000")
                .appFramework(.SwiftUI)
        )
        let autoCapturer = AutoCapturer(container: userpilot.container)
        let payload = ScreenTrackingPayload(
            currentScreen: "HomeScreen",
            screenClass: "NavigationStackHostingController<AnyView>",
            screenType: "UIViewController",
            navigationTitle: "Test Title here",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )

        XCTAssertEqual(
            autoCapturer.screenEventIdentity(
                screenClass: payload.screenClass,
                payload: payload
            ),
            "HomeScreen"
        )
    }

    func testScreenEventIdentity_keepsClassNameForUIKit() {
        let userpilot = MockUserpilot(
            config: Userpilot.Config(token: "NX-00000")
                .appFramework(.UIKit)
        )
        let autoCapturer = AutoCapturer(container: userpilot.container)
        let payload = ScreenTrackingPayload(
            currentScreen: "HomeScreen",
            screenClass: "HomeViewController",
            screenType: "UIViewController",
            navigationTitle: "Home",
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )

        XCTAssertEqual(
            autoCapturer.screenEventIdentity(
                screenClass: payload.screenClass,
                payload: payload
            ),
            "HomeViewController"
        )
    }
}
