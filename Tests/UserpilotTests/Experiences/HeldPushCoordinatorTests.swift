//
//  HeldPushCoordinatorTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the held push slot: the latest push wins, clear drops it, and a finished operation starts it in
//  place of the fake reload, which the started push then owes.
//

import XCTest
@testable import Userpilot

final class HeldPushCoordinatorTests: XCTestCase {

    private let logger = MockLogger()
    private var started: [(id: Int, owedReload: Bool)] = []
    private var admits = true
    private var reloadCount = 0
    private lazy var coordinator = HeldPushCoordinator(
        logger: logger,
        start: { [weak self] experience, owedReload in
            guard let self else { return false }
            self.started.append((experience.experienceId(), owedReload))
            return self.admits
        },
        publishFakeReload: { [weak self] in self?.reloadCount += 1 }
    )

    func testTheLatestPush_replacesAnOlderOne() throws {
        coordinator.hold(try push(id: 20))
        coordinator.hold(try push(id: 30))

        coordinator.onOperationFinished(owesReload: false)

        XCTAssertEqual(started.map(\.id), [30])
        let held = logger.loggedInfos.filter { $0 == "⏳ Server push held until the current experience ends" }
        XCTAssertEqual(held.count, 2)
    }

    func testClear_dropsTheHeldPush_soTheOwedReloadGoesOut() throws {
        coordinator.hold(try push(id: 20))

        coordinator.clear()
        coordinator.onOperationFinished(owesReload: true)

        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(reloadCount, 1)
    }

    func testFinish_startsTheHeldPush_insteadOfTheReload_handingItThatReload() throws {
        coordinator.hold(try push(id: 20))

        coordinator.onOperationFinished(owesReload: true)

        XCTAssertEqual(started.map(\.id), [20])
        XCTAssertEqual(started.map(\.owedReload), [true])
        XCTAssertEqual(reloadCount, 0)
    }

    func testFinish_withNothingHeld_publishesTheReloadOnlyWhenOwed() {
        coordinator.onOperationFinished(owesReload: false)
        XCTAssertEqual(reloadCount, 0)

        coordinator.onOperationFinished(owesReload: true)
        XCTAssertEqual(reloadCount, 1)
        XCTAssertTrue(started.isEmpty)
    }

    func testARefusedHeldPush_isConsumed_andTheOwedReloadStillGoesOut() throws {
        admits = false
        coordinator.hold(try push(id: 20))

        coordinator.onOperationFinished(owesReload: true)
        coordinator.onOperationFinished(owesReload: false)

        XCTAssertEqual(started.map(\.id), [20])
        XCTAssertEqual(reloadCount, 1)
    }

    func testAStartedPush_isConsumed() throws {
        coordinator.hold(try push(id: 20))

        coordinator.onOperationFinished(owesReload: false)
        coordinator.onOperationFinished(owesReload: true)

        XCTAssertEqual(started.map(\.id), [20])
        XCTAssertEqual(reloadCount, 1)
    }

    // MARK: - Helpers

    /// The Flow fixture as decoded server content, carrying `id`.
    private func push(id: Int) throws -> ExperienceContent {
        var response = MockContentFactory.makeFlowContentPayload()
        var content = response["mobile_contents"] as? [String: Any] ?? [:]
        content["id"] = id
        response["mobile_contents"] = content
        let json = try XCTUnwrap(response.toJSONString())
        return try XCTUnwrap(json.experienceCandidates().first)
    }
}
