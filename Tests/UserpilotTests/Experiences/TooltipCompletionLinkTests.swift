//
//  TooltipCompletionLinkTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Checks that completion navigation follows the selected tooltip action.
//

import XCTest
@testable import Userpilot

extension TooltipPagingTests {
    func testTargetTapDoesNotInheritButtonCompletionLink() {
        let sut = makeRevealedController(stepCount: 1, deepLinkOnStep: 0)
        var recorded: [URL] = []
        harness.userpilot.experiencesPublisher.onSetCompletionDeepLink = { recorded.append($0) }

        sut.onTargetTapped()

        XCTAssertTrue(recorded.isEmpty)
        XCTAssertEqual(harness.outcomes.last?.opensDeepLink, false)
    }

    func testCompletionUsesSelectedActionLink() {
        let sut = makeRevealedController(stepCount: 1, deepLinkOnStep: 0)
        var recorded: [URL] = []
        harness.userpilot.experiencesPublisher.onSetCompletionDeepLink = { recorded.append($0) }

        sut.handleAction(ButtonAction(buttonAction: "link", deepLink: "https://example.com/selected"))

        XCTAssertEqual(recorded.map(\.absoluteString), ["https://example.com/selected"])
        XCTAssertEqual(harness.outcomes.last?.opensDeepLink, true)
    }

}
