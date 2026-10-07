//
//  UserpilotInitializationTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies same-token startup, owner lifetime and weak delegate sharing without real services.
//

import XCTest
@testable import Userpilot

final class UserpilotInitializationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Userpilot.Registry.shared.resetForTesting()
        CountingUserpilot.initializations.value = 0
    }

    override func tearDown() {
        Userpilot.Registry.shared.resetForTesting()
        super.tearDown()
    }

    func testDuplicateInitialization_sharesFirstConfigurationAndServices() {
        let firstConfig = Userpilot.Config(token: "INIT-CONFIG").defaultInstance(false)
        let owner = CountingUserpilot(config: firstConfig)
        let alias = CountingUserpilot(config: Userpilot.Config(token: "INIT-CONFIG"))

        XCTAssertTrue(alias.config === firstConfig)
        XCTAssertTrue(alias.container === owner.container)
        XCTAssertTrue(alias.container.owner === owner)
        XCTAssertTrue(Userpilot.instance(forToken: "INIT-CONFIG") === owner)
        XCTAssertFalse(alias.config.isDefault)
        XCTAssertEqual(CountingUserpilot.initializations.value, 1)
    }

    func testDuplicateInitialization_retainsOwnerUntilLastFacadeIsReleased() {
        weak var weakOwner: Userpilot?
        var alias: Userpilot?
        var published: String?
        autoreleasepool {
            let owner = CountingUserpilot(config: Userpilot.Config(token: "INIT-LIFETIME"))
            weakOwner = owner
            owner.analyticsPublisher.onPublish = { published = $0.userId }
            alias = CountingUserpilot(config: Userpilot.Config(token: "INIT-LIFETIME"))
        }

        XCTAssertNotNil(weakOwner)
        XCTAssertTrue(alias?.container.owner === weakOwner)
        XCTAssertTrue(Userpilot.shared === weakOwner)
        alias?.identify(userId: "retained-owner")
        XCTAssertEqual(published, "retained-owner")

        alias = nil
        XCTAssertNil(weakOwner)
        XCTAssertNil(Userpilot.instance(forToken: "INIT-LIFETIME"))
    }

    func testDuplicateInitialization_sharesWeakDelegatesAndPendingLinkRouting() {
        let owner = CountingUserpilot(config: Userpilot.Config(token: "INIT-DELEGATES"))
        let alias = CountingUserpilot(config: Userpilot.Config(token: "INIT-DELEGATES"))
        weak var weakDelegate: InitializationDelegate?

        autoreleasepool {
            let delegate = InitializationDelegate()
            weakDelegate = delegate
            alias.navigationDelegate = delegate
            alias.analyticsDelegate = delegate
            alias.experienceDelegate = delegate
            XCTAssertTrue(owner.navigationDelegate === delegate)
            XCTAssertTrue(owner.analyticsDelegate === delegate)
            XCTAssertTrue(owner.experienceDelegate === delegate)
            XCTAssertTrue(owner.linkOpener.didProcessPendingDeepLink)

            owner.analyticsDelegate = nil
            XCTAssertNil(alias.analyticsDelegate)
            owner.analyticsDelegate = delegate
            XCTAssertTrue(alias.analyticsDelegate === delegate)
        }

        XCTAssertNil(weakDelegate)
        XCTAssertNil(owner.navigationDelegate)
        XCTAssertNil(alias.analyticsDelegate)
        XCTAssertNil(alias.experienceDelegate)
    }

    func testConcurrentInitialization_startsOneServiceContainer() throws {
        let completed = expectation(description: "concurrent initializers")
        completed.expectedFulfillmentCount = 24
        let instances = AtomicReference<[Userpilot]>([])

        for _ in 0..<24 {
            DispatchQueue.global().async {
                let instance = CountingUserpilot(config: Userpilot.Config(token: "INIT-CONCURRENT"))
                instances.update { $0 + [instance] }
                completed.fulfill()
            }
        }
        wait(for: [completed], timeout: 5)

        let owner = try XCTUnwrap(Userpilot.instance(forToken: "INIT-CONCURRENT"))
        XCTAssertEqual(CountingUserpilot.initializations.value, 1)
        XCTAssertEqual(Userpilot.Registry.shared.liveCount, 1)
        for instance in instances.value {
            XCTAssertTrue(instance.container === owner.container)
            XCTAssertTrue(instance.config === owner.config)
            XCTAssertTrue(instance.container.owner === owner)
        }
    }
}

private final class CountingUserpilot: MockUserpilot {
    static let initializations = AtomicReference(0)

    override func initializeContainer() {
        Self.initializations.update { $0 + 1 }
        super.initializeContainer()
    }
}

private final class InitializationDelegate: NSObject,
    UserpilotNavigationDelegate, UserpilotAnalyticsDelegate, UserpilotExperienceDelegate {
    func navigate(to url: URL) {}
    func didTrack(analytic: UserpilotAnalytic, value: String, properties: [String: Any]?) {}
    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?,
        experienceState: UserpilotExperienceState
    ) {}
    // swiftlint:disable:next function_parameter_count
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    ) {}
}
