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

    func testResolvedName_prefersSwiftUIScreenNameFromRootViewBeforeBridgePropagation() {
        let rootView = AnyView(
            Text("Home")
                .userpilotScreenName("HomeScreen")
        )
        let hostingController = UIHostingController(rootView: rootView)

        XCTAssertEqual(
            ScreenNameResolver.resolvedName(for: hostingController),
            "HomeScreen"
        )
    }
}
