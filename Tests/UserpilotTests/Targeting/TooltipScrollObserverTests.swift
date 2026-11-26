//
//  TooltipScrollObserverTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A waiting tooltip watches its host window's scroll views only while it waits, counts only
//  user-driven scrolling, and never touches a host delegate. A reveal ends a drag in progress.
//

import UIKit
import XCTest
@testable import Userpilot

final class TooltipScrollObserverTests: XCTestCase {

    func testAUserScroll_settlesOnce_whenItHasStopped() {
        let scrollView = UserScrollView()
        let recorder = SettleRecorder()
        let observer = TooltipScrollObserver(scrollViews: { [scrollView] })
        observer.delegate = recorder
        observer.start()
        addTeardownBlock { observer.stop() }
        let settled = expectation(description: "settled")
        recorder.onSettle = { settled.fulfill() }

        scrollView.scroll(to: 10)
        scrollView.scroll(to: 20)

        wait(for: [settled], timeout: 3)
        XCTAssertEqual(recorder.settles, 1)
    }

    func testProgrammaticScrolling_orAStoppedObserver_neverSettles() {
        let banner = UserScrollView()
        let scrolled = UserScrollView()
        let recorder = SettleRecorder()
        let watching = TooltipScrollObserver(scrollViews: { [banner] })
        let stopped = TooltipScrollObserver(scrollViews: { [scrolled] })
        [watching, stopped].forEach {
            $0.delegate = recorder
            $0.start()
        }
        addTeardownBlock { watching.stop() }
        let settled = expectation(description: "no settle")
        settled.isInverted = true
        recorder.onSettle = { settled.fulfill() }

        banner.contentOffset = CGPoint(x: 0, y: 40)
        scrolled.scroll(to: 10)
        stopped.stop()
        scrolled.scroll(to: 20)

        wait(for: [settled], timeout: 1.5)
    }

    func testObserving_neverAssignsOrChangesAHostDelegate() {
        let delegate = HostScrollDelegate()
        let withDelegate = UserScrollView()
        withDelegate.delegate = delegate
        let withoutDelegate = UserScrollView()
        let delegateClass = object_getClass(delegate).map(ObjectIdentifier.init)
        let observer = TooltipScrollObserver(scrollViews: { [withDelegate, withoutDelegate] })
        observer.start()

        withDelegate.scroll(to: 10)
        withoutDelegate.scroll(to: 10)
        observer.stop()

        XCTAssertTrue(withDelegate.delegate === delegate)
        XCTAssertNil(withoutDelegate.delegate)
        XCTAssertEqual(object_getClass(delegate).map(ObjectIdentifier.init), delegateClass)
    }

    func testReleasingAnObserverThatWasNotStopped_endsItsObservations() {
        let scrollView = UserScrollView()
        weak var released: TooltipScrollObserver?
        autoreleasepool {
            let observer = TooltipScrollObserver(scrollViews: { [scrollView] })
            observer.start()
            released = observer
        }

        XCTAssertNil(released)
        scrollView.scroll(to: 30)
    }

    func testDiscovery_findsVisibleScrollableScrollViews_includingNestedOnes() {
        let root = UIView()
        let outer = UIScrollView()
        let nested = UIScrollView()
        let locked = UIScrollView()
        locked.isScrollEnabled = false
        let hiddenContainer = UIView()
        hiddenContainer.isHidden = true
        hiddenContainer.addSubview(UIScrollView())
        outer.addSubview(nested)
        [outer, locked, hiddenContainer].forEach(root.addSubview)

        XCTAssertEqual(
            root.userpilotScrollViews().map(ObjectIdentifier.init), [outer, nested].map(ObjectIdentifier.init)
        )
        XCTAssertEqual(root.userpilotScrollViews(visitLimit: 2).map(ObjectIdentifier.init), [ObjectIdentifier(outer)])
    }

    func testParking_startsWatchingTheHostsScrollViews_andRecoveryEndingStopsIt() {
        var reads = 0
        let recovery = TooltipRecoveryController(
            retryIntervals: [],
            scrollObserver: TooltipScrollObserver(scrollViews: {
                reads += 1
                return []
            })
        ) { $0(.notFound) }

        recovery.attemptNow()
        XCTAssertEqual(reads, 1)
        recovery.scrollDidSettle()
        XCTAssertEqual(reads, 1, "A re-park keeps the running observation")
        recovery.cancel()
    }

    func testAUserScroll_reportsMovementAtOnce_andAProgrammaticOneDoesNot() {
        let scrollView = UserScrollView()
        let recorder = SettleRecorder()
        let observer = TooltipScrollObserver(scrollViews: { [scrollView] })
        observer.delegate = recorder
        observer.start()
        addTeardownBlock { observer.stop() }

        scrollView.contentOffset = CGPoint(x: 0, y: 5)
        let movesAfterProgrammaticScroll = recorder.moves
        scrollView.scroll(to: 10)

        XCTAssertEqual(movesAfterProgrammaticScroll, 0)
        XCTAssertEqual(recorder.moves, 1)
    }

    func testAnUnrecoverableFailureAfterTheLadder_stopsWatchingScrolls() {
        let scrollView = UserScrollView()
        let ended = expectation(description: "the failure ended recovery")
        let recovery = TooltipRecoveryController(
            retryIntervals: [0],
            scrollObserver: TooltipScrollObserver(scrollViews: { [scrollView] })
        ) { $0(.layoutUnavailable) }
        recovery.onUnrecoverableFailure = { _ in ended.fulfill() }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        wait(for: [ended], timeout: 1)
        scrollView.scroll(to: 10)
        recovery.scrollDidSettle()

        XCTAssertEqual(recovery.attemptCount, 2, "A scroll after the failure starts nothing")
    }

    func testCancellingADragInProgress_togglesOnlyATrackedScrollViewsPan_andLeavesItEnabled() {
        let tracked = TrackedScrollView()
        let idle = UIScrollView()
        var trackedChanges: [Bool] = []
        var idleChanges: [Bool] = []
        let observations = [
            tracked.panGestureRecognizer.observe(\.isEnabled, options: [.new]) { _, change in
                change.newValue.map { trackedChanges.append($0) }
            },
            idle.panGestureRecognizer.observe(\.isEnabled, options: [.new]) { _, change in
                change.newValue.map { idleChanges.append($0) }
            }
        ]

        tracked.userpilotCancelDragInProgress()
        idle.userpilotCancelDragInProgress()
        observations.forEach { $0.invalidate() }

        XCTAssertEqual(trackedChanges, [false, true])
        XCTAssertEqual(idleChanges, [])
        XCTAssertTrue(tracked.panGestureRecognizer.isEnabled)
    }
}

/// A scroll view with a finger down on it.
private final class TrackedScrollView: UIScrollView {
    override var isTracking: Bool { true }
}

/// A scroll view whose offset changes as if the user dragged it.
private final class UserScrollView: UIScrollView {
    private var isUserDragging = false
    override var isDragging: Bool { isUserDragging }

    func scroll(to offset: CGFloat) {
        isUserDragging = true
        contentOffset = CGPoint(x: 0, y: offset)
        isUserDragging = false
    }
}

private final class SettleRecorder: TooltipScrollDelegate {
    private(set) var settles = 0
    private(set) var moves = 0
    var onSettle: (() -> Void)?

    func scrollDidMove() {
        moves += 1
    }

    func scrollDidSettle() {
        settles += 1
        onSettle?()
    }
}

/// Stands in for the host app's own scroll delegate.
private final class HostScrollDelegate: NSObject, UIScrollViewDelegate {}
