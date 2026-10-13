//
//  UserpilotInitializationTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies same-token startup, owner lifetime and weak delegates without real services.
//

import XCTest
@testable import Userpilot

final class UserpilotInitializationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CountingUserpilot.constructions.value = 0
        CountingUserpilot.initializations.value = 0
    }

    func testSetup_returnsTheRegisteredObjectAndKeepsFirstConfigurationAndServices() {
        let config = Userpilot.Config(token: "INIT-CONFIG").defaultInstance(false)
        let first = CountingUserpilot.create(config: config)
        let second = CountingUserpilot.create(config: Userpilot.Config(token: config.token))

        XCTAssertTrue(second === first)
        XCTAssertTrue(second.config === config)
        XCTAssertTrue(second.container.owner === first)
        XCTAssertTrue(Userpilot.instance(forToken: config.token) === first)
        XCTAssertFalse(second.config.isDefault)
        XCTAssertEqual(CountingUserpilot.constructions.value, 1)
        XCTAssertEqual(CountingUserpilot.initializations.value, 1)
    }

    func testSetup_differentTokensHaveIndependentInstances() {
        let first = CountingUserpilot.create(config: Userpilot.Config(token: "INIT-A").defaultInstance(false))
        let second = CountingUserpilot.create(config: Userpilot.Config(token: "INIT-B").defaultInstance(false))

        XCTAssertFalse(first === second)
        XCTAssertFalse(first.container === second.container)
        XCTAssertEqual(CountingUserpilot.initializations.value, 2)
    }

    func testSetup_returnsOwnerUntilLastReferenceIsReleased() {
        weak var weakOwner: Userpilot?
        var second: Userpilot?
        var published: String?
        autoreleasepool {
            let first = CountingUserpilot.create(config: Userpilot.Config(token: "INIT-LIFETIME"))
            weakOwner = first
            first.analyticsPublisher.onPublish = { published = $0.userId }
            second = Userpilot.setup(config: Userpilot.Config(token: "INIT-LIFETIME"))
            XCTAssertTrue(second === first)
        }

        XCTAssertNotNil(weakOwner)
        XCTAssertTrue(Userpilot.shared === weakOwner)
        second?.identify(userId: "retained-owner")
        XCTAssertEqual(published, "retained-owner")

        second = nil
        XCTAssertNil(weakOwner)
        XCTAssertNil(Userpilot.instance(forToken: "INIT-LIFETIME"))
    }

    func testSetup_delegatesStayWeakAndNavigationAssignmentReplaysPendingLink() {
        let first = CountingUserpilot.create(config: Userpilot.Config(token: "INIT-DELEGATES"))
        let second = Userpilot.setup(config: Userpilot.Config(token: "INIT-DELEGATES"))
        weak var weakDelegate: InitializationDelegate?

        autoreleasepool {
            let delegate = InitializationDelegate()
            weakDelegate = delegate
            second.navigationDelegate = delegate
            second.analyticsDelegate = delegate
            second.experienceDelegate = delegate
            XCTAssertTrue(first.navigationDelegate === delegate)
            XCTAssertTrue(first.analyticsDelegate === delegate)
            XCTAssertTrue(first.experienceDelegate === delegate)
            XCTAssertTrue(first.linkOpener.didProcessPendingDeepLink)
        }

        XCTAssertNil(weakDelegate)
        XCTAssertNil(first.navigationDelegate)
        XCTAssertNil(first.analyticsDelegate)
        XCTAssertNil(first.experienceDelegate)
    }

    func testSetup_duplicateWarningUsesOriginalLogger() {
        let config = Userpilot.Config(token: "INIT-LOGGER").defaultInstance(false)
        let originalLogger = MockLogger()
        config.logger = originalLogger
        let first = CountingUserpilot.create(config: config)
        let newConfig = Userpilot.Config(token: config.token)
        let newLogger = MockLogger()
        newConfig.logger = newLogger

        let second = Userpilot.setup(config: newConfig)

        XCTAssertTrue(second === first)
        XCTAssertEqual(originalLogger.loggedErrors.filter { $0.contains("already initialized") }.count, 1)
        XCTAssertTrue(newLogger.loggedErrors.isEmpty)
    }

    func testSetup_duplicateCannotEnablePreviouslyDisabledLogging() {
        let first = CountingUserpilot.create(config: Userpilot.Config(token: "INIT-QUIET").defaultInstance(false))
        let newConfig = Userpilot.Config(token: first.config.token)
        let newLogger = MockLogger()
        newConfig.logger = newLogger

        let second = Userpilot.setup(config: newConfig)

        XCTAssertTrue(second === first)
        XCTAssertTrue(newLogger.loggedErrors.isEmpty)
    }

    func testSetup_duplicateCannotDisablePreviouslyEnabledLogging() {
        let config = Userpilot.Config(token: "INIT-LOGGING").defaultInstance(false)
        let originalLogger = MockLogger()
        config.logger = originalLogger
        let first = CountingUserpilot.create(config: config)

        let second = Userpilot.setup(config: Userpilot.Config(token: config.token).logging(enabled: false))

        XCTAssertTrue(second === first)
        XCTAssertEqual(originalLogger.loggedErrors.filter { $0.contains("already initialized") }.count, 1)
    }

    func testSetup_matchesTokensAfterTrimmingWhitespace() {
        let first = CountingUserpilot.create(config: Userpilot.Config(token: " \tINIT-TRIM\n").defaultInstance(false))
        let second = Userpilot.setup(config: Userpilot.Config(token: "INIT-TRIM"))
        let third = Userpilot.setup(config: Userpilot.Config(token: " INIT-TRIM "))

        XCTAssertTrue(second === first)
        XCTAssertTrue(third === first)
        XCTAssertEqual(first.config.token, "INIT-TRIM")
        XCTAssertTrue(Userpilot.instance(forToken: "INIT-TRIM") === first)
        XCTAssertEqual(CountingUserpilot.constructions.value, 1)
    }

    func testConcurrentSetup_constructsAndStartsOnlyOneObject() throws {
        let completed = expectation(description: "concurrent setups")
        completed.expectedFulfillmentCount = 24
        let instances = AtomicReference<[Userpilot]>([])

        for _ in 0..<24 {
            DispatchQueue.global().async {
                let config = Userpilot.Config(token: "INIT-CONCURRENT").defaultInstance(false)
                let instance = CountingUserpilot.create(config: config)
                instances.update { $0 + [instance] }
                completed.fulfill()
            }
        }
        wait(for: [completed], timeout: 5)

        let owner = try XCTUnwrap(Userpilot.instance(forToken: "INIT-CONCURRENT"))
        XCTAssertEqual(CountingUserpilot.constructions.value, 1)
        XCTAssertEqual(CountingUserpilot.initializations.value, 1)
        XCTAssertEqual(instances.value.count, 24)
        XCTAssertTrue(instances.value.allSatisfy { $0 === owner })
    }

    func testSecondDefaultClaim_keepsFirstDefaultAndStartsSecondInstance() {
        let runtime = UserpilotRuntime()
        let firstConfig = Userpilot.Config(token: "INIT-DEFAULT-A")
        let secondConfig = Userpilot.Config(token: "INIT-DEFAULT-B")
        let logger = MockLogger()
        secondConfig.logger = logger

        let first = runtime.initializeInstance(config: firstConfig) { CountingUserpilot(config: firstConfig) }
        let second = runtime.initializeInstance(config: secondConfig) { CountingUserpilot(config: secondConfig) }

        XCTAssertTrue(runtime.instanceRegistry.default === first)
        XCTAssertTrue(runtime.instanceRegistry.isRegistered(second))
        XCTAssertEqual(CountingUserpilot.initializations.value, 2)
        XCTAssertEqual(logger.loggedErrors.filter { $0.contains("isDefault is already claimed") }.count, 1)
    }

    func testInternalConstruction_doesNotRegisterOrStartServices() {
        let instance = CountingUserpilot(config: Userpilot.Config(token: "INIT-PASSIVE"))

        XCTAssertNil(Userpilot.instance(forToken: instance.config.token))
        XCTAssertEqual(CountingUserpilot.initializations.value, 0)
    }
}

private final class CountingUserpilot: MockUserpilot {
    static let constructions = AtomicReference(0)
    static let initializations = AtomicReference(0)

    override init(config: Config) {
        Self.constructions.update { $0 + 1 }
        super.init(config: config)
    }

    static func create(config: Config) -> CountingUserpilot {
        let instance = Userpilot.setup(config: config) { CountingUserpilot(config: $0) }
        guard let counted = instance as? CountingUserpilot else {
            preconditionFailure("Initialization tests must use their own tokens")
        }
        return counted
    }

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
