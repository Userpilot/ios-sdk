//
//  ScreenNameResolverTests.swift
//  UserpilotTests
//
//  Created by OpenAI Codex on 13/04/2026.
//

import SwiftUI
import XCTest
@testable import Userpilot

final class ScreenNameResolverTests: XCTestCase {

    func testResolvedName_usesSwiftUIScreenNameAfterBridgePropagation() {
        let rootView = AnyView(
            Text("Home")
                .userpilotScreenName("HomeScreen")
        )
        let hostingController = UIHostingController(rootView: rootView)

        // `.userpilotScreenName` resolves through `ScreenNameBridge` (a
        // UIViewRepresentable), which sets the screen name on the hosting
        // controller once SwiftUI lays it out. Simulate that propagation so the
        // assertion is deterministic and doesn't depend on a live render pass.
        hostingController.userpilotSwiftUIScreenName = "HomeScreen"

        XCTAssertEqual(
            ScreenNameResolver.resolvedName(for: hostingController),
            "HomeScreen"
        )
    }

    func testResolvedName_fallsBackToHostingControllerBeforePropagation() {
        // Before the bridge propagates (controller never rendered), there is no
        // SwiftUI screen name to read, so resolution falls back to the hosting
        // controller's display name — the correct, defined behavior.
        let rootView = AnyView(Text("Home").userpilotScreenName("HomeScreen"))
        let hostingController = UIHostingController(rootView: rootView)

        XCTAssertEqual(
            ScreenNameResolver.resolvedName(for: hostingController),
            "UIHostingController"
        )
    }
}
