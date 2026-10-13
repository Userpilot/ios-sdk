//
//  UserpilotInitializationTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies instance startup, owner lifetime and weak delegates without real services.
//

import XCTest
@testable import Userpilot

final class UserpilotInitializationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CountingUserpilot.initializations.value = 0
    }

    func testInitialization_registersOwnerBeforeStartingServices() {
        let config = Userpilot.Config(token: "INIT-CONFIG").defaultInstance(false)
        let instance = CountingUserpilot(config: config)

        XCTAssertTrue(instance.config === config)
        XCTAssertTrue(instance.container.owner === instance)
        XCTAssertTrue(Userpilot.instance(forToken: config.token) === instance)
        XCTAssertTrue(instance.wasRegisteredDuringStartup)
        XCTAssertEqual(CountingUserpilot.initializations.value, 1)
    }

    func testInitialization_differentTokensHaveIndependentServicesAndConfiguration() {
        let first = CountingUserpilot(config: Userpilot.Config(token: "INIT-A").defaultInstance(false))
        let second = CountingUserpilot(config: Userpilot.Config(token: "INIT-B").defaultInstance(false))

        XCTAssertFalse(first.container === second.container)
        XCTAssertFalse(first.analyticsPublisher === second.analyticsPublisher)
        XCTAssertFalse(first.socketManager === second.socketManager)
        XCTAssertFalse(first.config === second.config)
        XCTAssertTrue(Userpilot.instance(forToken: "INIT-A") === first)
        XCTAssertTrue(Userpilot.instance(forToken: "INIT-B") === second)
        XCTAssertEqual(CountingUserpilot.initializations.value, 2)
    }

    func testInitialization_releasesOwnerWhenTheHostDropsItsReference() {
        weak var weakOwner: Userpilot?
        var retained: Userpilot?
        var published: String?
        autoreleasepool {
            let instance = CountingUserpilot(config: Userpilot.Config(token: "INIT-LIFETIME"))
            weakOwner = instance
            instance.analyticsPublisher.onPublish = { published = $0.userId }
            retained = instance
        }

        XCTAssertNotNil(weakOwner)
        XCTAssertTrue(Userpilot.shared === weakOwner)
        retained?.identify(userId: "retained-owner")
        XCTAssertEqual(published, "retained-owner")

        retained = nil
        XCTAssertNil(weakOwner)
        XCTAssertNil(Userpilot.instance(forToken: "INIT-LIFETIME"))
    }

    func testInitialization_delegatesStayWeakAndNavigationAssignmentReplaysPendingLink() {
        let instance = CountingUserpilot(config: Userpilot.Config(token: "INIT-DELEGATES"))
        weak var weakDelegate: InitializationDelegate?
        instance.linkOpener.didProcessPendingDeepLink = false

        autoreleasepool {
            let delegate = InitializationDelegate()
            weakDelegate = delegate
            instance.navigationDelegate = delegate
            instance.analyticsDelegate = delegate
            instance.experienceDelegate = delegate
            XCTAssertTrue(instance.navigationDelegate === delegate)
            XCTAssertTrue(instance.analyticsDelegate === delegate)
            XCTAssertTrue(instance.experienceDelegate === delegate)
            XCTAssertTrue(instance.linkOpener.didProcessPendingDeepLink)
        }

        XCTAssertNil(weakDelegate)
        XCTAssertNil(instance.navigationDelegate)
        XCTAssertNil(instance.analyticsDelegate)
        XCTAssertNil(instance.experienceDelegate)
    }

    func testInitialization_trimsTokenBeforeRegistrationAndServiceConfiguration() {
        let config = Userpilot.Config(token: " \tINIT-TRIM\n").defaultInstance(false)
        let instance = CountingUserpilot(config: config)
        let serviceConfig = instance.container.resolve(Userpilot.Config.self)

        XCTAssertEqual(instance.config.token, "INIT-TRIM")
        XCTAssertEqual(serviceConfig.token, "INIT-TRIM")
        XCTAssertTrue(Userpilot.instance(forToken: "INIT-TRIM") === instance)
    }

    func testConcurrentInitialization_keepsDifferentTokensIsolated() {
        let completed = expectation(description: "independent instances initialized")
        completed.expectedFulfillmentCount = 8
        let instances = AtomicReference<[CountingUserpilot]>([])

        for index in 0..<8 {
            DispatchQueue.global().async {
                let config = Userpilot.Config(token: "INIT-CONCURRENT-\(index)").defaultInstance(false)
                let instance = CountingUserpilot(config: config)
                instances.update { $0 + [instance] }
                completed.fulfill()
            }
        }
        wait(for: [completed], timeout: 5)

        XCTAssertEqual(CountingUserpilot.initializations.value, 8)
        XCTAssertEqual(Set(instances.value.map { ObjectIdentifier($0.container) }).count, 8)
        XCTAssertTrue(instances.value.allSatisfy {
            $0.wasRegisteredDuringStartup && Userpilot.instance(forToken: $0.config.token) === $0
        })
    }

    func testSecondDefaultClaim_keepsFirstDefaultAndStartsSecondInstance() {
        let first = CountingUserpilot(config: Userpilot.Config(token: "INIT-DEFAULT-A"))
        let secondConfig = Userpilot.Config(token: "INIT-DEFAULT-B")
        let logger = MockLogger()
        secondConfig.logger = logger
        let second = CountingUserpilot(config: secondConfig)

        XCTAssertTrue(Userpilot.shared === first)
        XCTAssertTrue(Userpilot.instance(forToken: secondConfig.token) === second)
        XCTAssertEqual(CountingUserpilot.initializations.value, 2)
        XCTAssertEqual(logger.loggedErrors.filter { $0.contains("isDefault is already claimed") }.count, 1)
    }
}

private final class CountingUserpilot: MockUserpilot {
    static let initializations = AtomicReference(0)
    private(set) var wasRegisteredDuringStartup = false

    override func initializeContainer() {
        Self.initializations.update { $0 + 1 }
        wasRegisteredDuringStartup = Userpilot.instance(forToken: config.token) === self
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
