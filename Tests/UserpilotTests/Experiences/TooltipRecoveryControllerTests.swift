//
//  TooltipRecoveryControllerTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies retry deferral, parking and cancellation without a live backend.
//

import XCTest
@testable import Userpilot

final class TooltipRecoveryControllerTests: XCTestCase {
    func testCancelledAsyncReadDoesNotParkOrRetry() {
        var reply: ((TargetResolutionError?) -> Void)?
        let recovery = TooltipRecoveryController(retryIntervals: []) { reply = $0 }
        recovery.onSearchFailed = { _, _ in XCTFail("Cancelled read must not park") }
        recovery.attemptNow()
        recovery.scrollDidSettle()
        XCTAssertEqual(recovery.attemptCount, 1)
        recovery.cancel()
        reply?(.notFound)
        recovery.scrollDidSettle()
        XCTAssertEqual(recovery.attemptCount, 1)
    }

    func testStoppedOrRetargetedCoordinatorIgnoresStaleSuccess() {
        var replies: [(Result<ResolvedTarget, TargetResolutionError>) -> Void] = []
        var reveals = 0
        let coordinator = TooltipTargetCoordinator(resolveTarget: { replies.append($0) }, isScreenAtEnd: { $0(true) })
        coordinator.scheduleStillnessCheck = { _, work in work() }
        coordinator.onResolved = { _ in reveals += 1 }
        coordinator.start(retryIntervals: [])
        coordinator.retarget(retryIntervals: [])
        let result = ResolvedTarget(rect: CGRect(x: 10, y: 20, width: 30, height: 40),
                                    score: 1, nodeID: "dom", view: nil)
        replies[0](.success(result))
        XCTAssertEqual(reveals, 0)
        replies[1](.success(result))
        XCTAssertEqual(reveals, 0, "The stillness re-read is still out")
        replies[2](.success(result))
        XCTAssertEqual(reveals, 1)
        coordinator.retarget(retryIntervals: [])
        coordinator.stop()
        replies[3](.success(result))
        XCTAssertEqual(reveals, 1)
    }

    func testZeroRetryDefersThenEveryFailedSearchAfterTheLadderIsReported() {
        var attempts = 0
        var reported: [Int] = []
        let parked = expectation(description: "zero-delay retry parks")
        let recovery = TooltipRecoveryController(retryIntervals: [0]) { completion in
            attempts += 1
            completion(.notFound)
        }
        recovery.onSearchFailed = { _, attemptCount in
            reported.append(attemptCount)
            if reported.count == 1 { parked.fulfill() }
        }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(reported, [])
        wait(for: [parked], timeout: 1)
        XCTAssertEqual(reported, [2])
        recovery.scrollDidSettle()
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(reported, [2, 3])
    }

    func testEmptyRetryLadderParksAndRecoversOnScroll() {
        var shouldFail = true
        var exhaustion = 0
        let recovery = TooltipRecoveryController(retryIntervals: []) { completion in
            completion(shouldFail ? .notFound : nil)
        }
        recovery.onSearchFailed = { _, _ in exhaustion += 1 }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        XCTAssertEqual(recovery.attemptCount, 1)
        XCTAssertEqual(exhaustion, 1)
        shouldFail = false
        recovery.scrollDidSettle()
        XCTAssertEqual(recovery.attemptCount, 2)
        XCTAssertEqual(exhaustion, 1)
    }

    func testCancelRejectsQueuedRetryAndStaleScrollCallback() {
        let drained = expectation(description: "main queue drained")
        let recovery = TooltipRecoveryController(retryIntervals: [0]) { $0(.notFound) }
        recovery.attemptNow()
        recovery.cancel()
        recovery.scrollDidSettle()
        performOn(.main) { drained.fulfill() }
        wait(for: [drained], timeout: 1)

        XCTAssertEqual(recovery.attemptCount, 1)
    }

    func testCancelDuringTheFailureCallbackDoesNotRestartRecovery() {
        let recovery = TooltipRecoveryController(retryIntervals: []) { $0(.notFound) }
        recovery.onSearchFailed = { [weak recovery] _, _ in recovery?.cancel() }
        recovery.attemptNow()
        recovery.scrollDidSettle()

        XCTAssertEqual(recovery.attemptCount, 1)
    }

    func testUnrecoverableTargetSettlesWithoutParking() {
        var failures = 0
        var exhaustion = 0
        let recovery = TooltipRecoveryController(retryIntervals: [0]) { $0(.invalidSelector) }
        recovery.onUnrecoverableFailure = { _ in failures += 1 }
        recovery.onSearchFailed = { _, _ in exhaustion += 1 }

        recovery.attemptNow()
        XCTAssertEqual(failures, 1)
        XCTAssertEqual(exhaustion, 0)
        recovery.cancel()
    }

    // MARK: Target alerts

    func testNotFoundWaitsForTheEndOfTheScreenAndThenAlerts() {
        var atEnd = false
        var alerts: [String] = []
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(.failure(.notFound)) },
            isScreenAtEnd: { $0(atEnd) }
        )
        coordinator.onTargetNotFound = { error, attempts, _ in alerts.append("\(error.reason) \(attempts)") }
        addTeardownBlock { coordinator.stop() }

        coordinator.start(retryIntervals: [])
        XCTAssertEqual(alerts, [])
        atEnd = true
        // A later search, as on a scroll stop.
        coordinator.handleRotation()
        XCTAssertEqual(alerts, ["not_found 2"])
    }

    func testAScreenThatDoesNotScrollSendsNotFoundWhenTheLadderIsSpent() {
        var alerts: [String] = []
        let alerted = expectation(description: "alert after the ladder")
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(.failure(.notFound)) },
            isScreenAtEnd: { $0(true) }
        )
        coordinator.onTargetNotFound = { error, attempts, _ in
            alerts.append("\(error.reason) \(attempts)")
            alerted.fulfill()
        }
        addTeardownBlock { coordinator.stop() }

        coordinator.start(retryIntervals: [0])
        XCTAssertEqual(alerts, [])
        wait(for: [alerted], timeout: 1)
        XCTAssertEqual(alerts, ["not_found 2"])
    }

    func testAmbiguousNotVisibleAndOverlappedAlertAfterTheLadderWithoutAScreenEndCheck() {
        let errors: [TargetResolutionError] = [
            .ambiguous(matchCount: 2), .notVisible(matchCount: 1), .overlapped(matchCount: 1)
        ]
        for error in errors {
            var checks = 0
            var alerts: [String] = []
            let coordinator = TooltipTargetCoordinator(
                resolveTarget: { $0(.failure(error)) },
                isScreenAtEnd: { completion in
                    checks += 1
                    completion(false)
                }
            )
            coordinator.onTargetNotFound = { error, attempts, _ in alerts.append("\(error.reason) \(attempts)") }

            coordinator.start(retryIntervals: [])
            XCTAssertEqual(alerts, ["\(error.reason) 1"])
            XCTAssertEqual(checks, 0)
            coordinator.stop()
        }
    }

    func testATargetFoundWhileTheScreenEndCheckRunsSendsNoAlert() {
        var pendingAnswer: ((Bool) -> Void)?
        var found = false
        var alerts = 0
        let target = ResolvedTarget(rect: CGRect(x: 10, y: 20, width: 30, height: 40),
                                    score: 1, nodeID: "dom", view: nil)
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(found ? .success(target) : .failure(.notFound)) },
            isScreenAtEnd: { pendingAnswer = $0 }
        )
        coordinator.onTargetNotFound = { _, _, _ in alerts += 1 }
        addTeardownBlock { coordinator.stop() }

        coordinator.start(retryIntervals: [])
        found = true
        coordinator.handleRotation()
        pendingAnswer?(true)
        XCTAssertEqual(alerts, 0)
    }

    // MARK: After reveal

    func testAVisibleTargetSurvivesOneFailedReMatch_whateverTheLadder_andIsLostOnTheSecondInARow() {
        var failing = false
        var lost = 0
        let target = ResolvedTarget(rect: CGRect(x: 10, y: 20, width: 30, height: 40),
                                    score: 1, nodeID: "dom", view: nil)
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(failing ? .failure(.notFound) : .success(target)) },
            isScreenAtEnd: { $0(true) }
        )
        coordinator.onTargetLost = { lost += 1 }
        addTeardownBlock { coordinator.stop() }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let resize = { (width: CGFloat) in
            container.frame.size.width = width
            container.layoutIfNeeded()
        }

        coordinator.start(retryIntervals: Constants.Theme.tooltipRetryIntervals)
        coordinator.beginTracking(in: container)
        failing = true
        resize(200)
        failing = false
        resize(250)
        failing = true
        resize(300)
        XCTAssertEqual(lost, 0, "A success resets the run; one failure is within the budget")
        resize(350)
        XCTAssertEqual(lost, 1)
        XCTAssertEqual(TooltipTargetCoordinator.postRevealFailureBudget, 1)
    }
}
