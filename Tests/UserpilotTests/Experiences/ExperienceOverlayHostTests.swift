//
//  ExperienceOverlayHostTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that a detached overlay waits for a real app window, including legacy UIKit hosts.
//

import UIKit
import XCTest
@testable import Userpilot

final class ExperienceOverlayHostTests: XCTestCase {
    func testDetachedOverlayNeedsVisibleLegacyAppWindow() {
        let owner = MockUserpilot.make(config: Userpilot.Config(token: UUID().uuidString).defaultInstance(false))
        let overlay = ExperienceOverlayWindow(owningInstance: owner)
        overlay.windowScene = nil
        let hostWindow = MockLegacyHostWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        hostWindow.windowScene = nil
        hostWindow.rootViewController = UIViewController()
        defer {
            hostWindow.isHidden = true
            hostWindow.rootViewController = nil
            overlay.teardown()
        }

        // Model a scene-less app independently of the runner's own windows. The publisher
        // supplies this same native window list from UIApplication in a client app.
        let appWindows = [overlay, hostWindow]
        XCTAssertNotNil(overlay.rootViewController)
        XCTAssertFalse(overlay.isReadyForPresentation(in: appWindows))
        hostWindow.isHidden = false
        XCTAssertTrue(overlay.isReadyForPresentation(in: appWindows))
        hostWindow.isHidden = true
        XCTAssertFalse(overlay.isReadyForPresentation(in: appWindows))
    }
}

/// Controls visibility independently of the runner's scene while testing the real readiness
/// policy. The fixture does not attempt an actual UIKit presentation.
private final class MockLegacyHostWindow: UIWindow {
    private var simulatedHidden = true

    override var isHidden: Bool {
        get { simulatedHidden }
        set { simulatedHidden = newValue }
    }
}
