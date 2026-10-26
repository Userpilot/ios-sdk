//
//  ExperienceOverlaySceneTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 25/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  App-hosted iPad check that the next presentation follows the user to the scene they are in.
//

import UIKit
import XCTest
@testable import Userpilot

final class ExperienceOverlaySceneTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var openedSessions: [UISceneSession] = []

    override func tearDown() {
        openedSessions.forEach { UIApplication.shared.requestSceneSessionDestruction($0, options: nil) }
        openedSessions = []
        userpilot = nil
        super.tearDown()
    }

    func testIdleOverlayMovesToTheForegroundSceneBeforePresenting() throws {
        try XCTSkipUnless(UIApplication.shared.supportsMultipleScenes,
                          "Needs the app-hosted iPad run of scripts/test-declarative-rendering.sh")
        userpilot = MockUserpilot(config: Userpilot.Config(token: "SCENE-\(UUID().uuidString)").defaultInstance(false))
        let overlay = userpilot.experienceOverlayWindow
        let original = try XCTUnwrap(overlay.windowScene)
        let existingSessions = Set(UIApplication.shared.openSessions)

        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { error in
            XCTFail("Second scene failed to open: \(error)")
        }
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            original.activationState != .foregroundActive && !UIApplication.shared.activeWindowScenes.isEmpty
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 20), .completed, "The original scene never left")
        openedSessions = Array(Set(UIApplication.shared.openSessions).subtracting(existingSessions))

        overlay.prepareForPresentation()

        XCTAssertFalse(overlay.windowScene === original, "Overlay stayed on the scene the user left")
        XCTAssertEqual(overlay.windowScene?.activationState, .foregroundActive)
        XCTAssertEqual(overlay.frame, overlay.windowScene?.coordinateSpace.bounds)
    }
}
