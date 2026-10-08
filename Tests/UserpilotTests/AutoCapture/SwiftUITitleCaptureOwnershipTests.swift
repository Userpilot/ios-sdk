//
//  SwiftUITitleCaptureOwnershipTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that installed native lifecycle hooks use the appearing controller's SDK owner.
//

import XCTest
@testable import Userpilot

private final class OwnedHostingController: UIViewController {}

final class SwiftUITitleCaptureOwnershipTests: XCTestCase {
    private var defaultInstance: MockUserpilot!
    private var ownerInstance: MockUserpilot!

    override func setUp() {
        super.setUp()
        Userpilot.Registry.shared.resetForTesting()
        SwiftUICaptureHealth._resetForTesting()
        SwiftUIScanCache.shared.stop()
    }

    override func tearDown() {
        SwiftUIScanCache.shared.stop()
        defaultInstance = nil
        ownerInstance = nil
        Userpilot.Registry.shared.resetForTesting()
        SwiftUICaptureHealth._resetForTesting()
        super.tearDown()
    }

    func testAppearingOwnerOptedOut_doesNotUseEnabledDefault() throws {
        try configure(defaultEnabled: true, ownerEnabled: false)
        appearWithCachedTitle()
        XCTAssertEqual(SwiftUIScanCache.shared.inventory().0.map(\.title), ["Save"])
    }

    func testAppearingOwnerOptedIn_doesNotUseDisabledDefault() throws {
        try configure(defaultEnabled: false, ownerEnabled: true)
        appearWithCachedTitle()
        XCTAssertTrue(SwiftUIScanCache.shared.inventory().0.isEmpty,
                      "The enabled owner's appearance must invalidate the previous screen snapshot")
    }

    private func configure(defaultEnabled: Bool, ownerEnabled: Bool) throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("SwiftUI button autocapture runs on iOS 26 and later only")
        }
        func config(enabled: Bool) -> Userpilot.Config {
            let config = Userpilot.Config(token: "NX-\(UUID().uuidString)")
                .enableInteractionAutoCapture(true)
                .enableSwiftUIButtonAutoCapture(enabled)
            config.appFramework = .SwiftUI
            return config
        }
        defaultInstance = MockUserpilot(config: config(enabled: defaultEnabled))
        ownerInstance = MockUserpilot(config: config(enabled: ownerEnabled)
            .attach(viewControllerClasses: [OwnedHostingController.self]))
        // Install the same process-wide hook used in production, through the enabled coordinator.
        _ = defaultInstance.autoCaptureCoordinator
        _ = ownerInstance.autoCaptureCoordinator
    }

    private func appearWithCachedTitle() {
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: [],
            inventory: [.init(title: "Save", viewType: "Button", depth: 0, order: 0)]
        )
        let controller = OwnedHostingController()
        controller.loadViewIfNeeded()
        controller.viewDidAppear(false)
    }
}
