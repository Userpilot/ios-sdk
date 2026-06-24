//
//  ScreenNameResolverTests.swift
//  UserpilotTests
//
//  Created by OpenAI Codex on 13/04/2026.
//

import XCTest
@testable import Userpilot

final class ScreenNameResolverTests: XCTestCase {

    func testResolvedName_prefersBridgedSwiftUIScreenName() {
        let hostingController = UIViewController()
        hostingController.userpilotSwiftUIScreenName = "HomeScreen"

        XCTAssertEqual(
            ScreenNameResolver.resolvedName(for: hostingController),
            "HomeScreen"
        )
    }
}
