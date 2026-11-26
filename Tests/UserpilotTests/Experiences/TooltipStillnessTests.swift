//
//  TooltipStillnessTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A found target reveals only once it holds still, and nothing is attempted while the user
//  scrolls: a scroll pauses the retry ladder until the screen settles.
//

import XCTest
@testable import Userpilot

final class TooltipStillnessTests: XCTestCase {

    // MARK: Stillness before reveal

    func testAFoundTarget_revealsOnlyOnceTwoLookupsAStillnessIntervalApartAgree() {
        var tops: [CGFloat] = [0, 40, 80, 80]
        var revealedTops: [CGFloat] = []
        let clock = StillnessClock()
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(Self.found(top: tops.removeFirst())) },
            isScreenAtEnd: { $0(true) }
        )
        coordinator.scheduleStillnessCheck = clock.schedule
        coordinator.onResolved = { revealedTops.append($0.minY) }
        addTeardownBlock { coordinator.stop() }

        coordinator.start(retryIntervals: [])
        clock.tick()
        clock.tick()
        let revealedWhileMoving = revealedTops
        clock.tick()

        XCTAssertEqual(revealedWhileMoving, [])
        XCTAssertEqual(revealedTops, [80])
        XCTAssertEqual(coordinator.attemptCount, 1)
    }

    func testATargetThatLeavesWhileItIsConfirmed_isAFailedAttempt() {
        var replies: [Result<ResolvedTarget, TargetResolutionError>] = [Self.found(top: 0), .failure(.notFound)]
        var reveals = 0
        var failedAttempts = 0
        var scrollViewReads = 0
        let clock = StillnessClock()
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(replies.isEmpty ? .failure(.notFound) : replies.removeFirst()) },
            isScreenAtEnd: { $0(false) },
            scrollViews: {
                scrollViewReads += 1
                return []
            }
        )
        coordinator.scheduleStillnessCheck = clock.schedule
        coordinator.onResolved = { _ in reveals += 1 }
        coordinator.onAttemptFailed = { failedAttempts += 1 }
        addTeardownBlock { coordinator.stop() }

        coordinator.start(retryIntervals: [])
        clock.tick()

        XCTAssertEqual(reveals, 0)
        XCTAssertEqual(failedAttempts, 1)
        XCTAssertEqual(scrollViewReads, 1, "The failure parks and watches the host's scroll views")
    }

    func testATargetThatNeverStops_revealsAtItsLatestPositionAfterTheStillnessTimeout() {
        var top: CGFloat = 0
        var revealedTops: [CGFloat] = []
        let clock = StillnessClock()
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { completion in
                completion(Self.found(top: top))
                top += 10
            },
            isScreenAtEnd: { $0(true) }
        )
        coordinator.scheduleStillnessCheck = clock.schedule
        coordinator.onResolved = { revealedTops.append($0.minY) }
        addTeardownBlock { coordinator.stop() }
        let checks = Int((Constants.Theme.tooltipStillnessTimeout / Constants.Theme.tooltipStillnessInterval).rounded())

        coordinator.start(retryIntervals: [])
        (1..<checks).forEach { _ in clock.tick() }
        let revealedBeforeTimeout = revealedTops
        clock.tick()

        XCTAssertEqual(revealedBeforeTimeout, [])
        XCTAssertEqual(revealedTops, [200])
    }

    func testARevealedTarget_reMatchesItsGeometryWithoutWaitingForStillness() {
        var reads = 0
        var reveals = 0
        let clock = StillnessClock()
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { completion in
                reads += 1
                completion(Self.found(top: 0))
            },
            isScreenAtEnd: { $0(true) }
        )
        coordinator.scheduleStillnessCheck = clock.schedule
        coordinator.onResolved = { _ in reveals += 1 }
        addTeardownBlock { coordinator.stop() }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        coordinator.start(retryIntervals: [])
        clock.tick()
        coordinator.beginTracking(in: container)
        let readsBeforeGeometryChange = reads

        container.frame.size.width = 200
        container.layoutIfNeeded()

        XCTAssertEqual(reads - readsBeforeGeometryChange, 1)
        XCTAssertEqual(reveals, 2)
    }

    func testAVisibleTarget_reMatchesWhenTheHostSettles_andAMissIsCheckedOnceMoreBeforeItIsLost() {
        var isFound = true
        var reveals = 0
        var lost = 0
        let clock = StillnessClock()
        let coordinator = TooltipTargetCoordinator(
            resolveTarget: { $0(isFound ? Self.found(top: 0) : .failure(.notFound)) },
            isScreenAtEnd: { $0(true) }
        )
        coordinator.scheduleStillnessCheck = clock.schedule
        coordinator.onResolved = { _ in reveals += 1 }
        coordinator.onTargetLost = { lost += 1 }
        addTeardownBlock { coordinator.stop() }
        coordinator.start(retryIntervals: [])
        clock.tick()
        coordinator.beginTracking(in: UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)))

        coordinator.scrollDidSettle()
        isFound = false
        coordinator.scrollDidSettle()
        let lostAfterOneMiss = lost
        clock.tick()

        XCTAssertEqual(reveals, 2)
        XCTAssertEqual(lostAfterOneMiss, 0)
        XCTAssertEqual(lost, 1)
    }

    // MARK: Scrolling pauses the ladder

    func testAScroll_cancelsThePendingRetry_andTheLadderResumesAfterTheSettle() {
        var attempts = 0
        let resumed = expectation(description: "the ladder's next rung ran")
        let recovery = TooltipRecoveryController(retryIntervals: [50, 50]) { completion in
            attempts += 1
            if attempts == 3 { resumed.fulfill() }
            completion(.notFound)
        }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        recovery.scrollDidMove()
        waitOnMain(seconds: 0.2)
        let attemptsWhileScrolling = attempts
        recovery.scrollDidSettle()
        let attemptsAfterSettle = attempts
        wait(for: [resumed], timeout: 1)

        XCTAssertEqual(attemptsWhileScrolling, 1)
        XCTAssertEqual(attemptsAfterSettle, 2)
        XCTAssertEqual(attempts, 3)
    }

    func testASettleWithoutAScroll_leavesTheLaddersTimingAlone() {
        var attempts = 0
        let retried = expectation(description: "the ladder's rung ran")
        let recovery = TooltipRecoveryController(retryIntervals: [50]) { completion in
            attempts += 1
            if attempts == 2 { retried.fulfill() }
            completion(.notFound)
        }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        recovery.scrollDidSettle()
        let attemptsAfterSettle = attempts
        wait(for: [retried], timeout: 1)

        XCTAssertEqual(attemptsAfterSettle, 1)
        XCTAssertEqual(attempts, 2)
    }

    func testAScroll_abandonsTheReadInFlight_andTheSettleReadsAgain() {
        var replies: [(TargetResolutionError?) -> Void] = []
        var abandoned = 0
        let recovery = TooltipRecoveryController(retryIntervals: [50]) { replies.append($0) }
        recovery.onAttemptAbandoned = { abandoned += 1 }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        recovery.scrollDidMove()
        replies[0](nil)
        recovery.scrollDidSettle()

        XCTAssertEqual(abandoned, 1)
        XCTAssertEqual(replies.count, 2, "The late success was ignored, so the settle read again")
    }

    // MARK: Helpers

    private static func found(top: CGFloat) -> Result<ResolvedTarget, TargetResolutionError> {
        .success(ResolvedTarget(rect: CGRect(x: 0, y: top, width: 10, height: 10), score: 1, nodeID: "dom", view: nil))
    }

    private func waitOnMain(seconds: TimeInterval) {
        let elapsed = expectation(description: "\(seconds)s elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { elapsed.fulfill() }
        wait(for: [elapsed], timeout: seconds + 1)
    }
}

/// Holds stillness re-reads until the test lets one interval pass.
private final class StillnessClock {
    private var due: [() -> Void] = []

    func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        due.append(work)
    }

    func tick() {
        let checks = due
        due = []
        checks.forEach { $0() }
    }
}
