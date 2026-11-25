//
//  TooltipLayoutObserverTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A waiting tooltip also retries once its host window's layout has stopped changing for a
//  second, without a scroll. Only visible geometry counts as a change.
//

import UIKit
import XCTest
@testable import Userpilot

final class TooltipLayoutObserverTests: XCTestCase {

    func testALayoutChange_settlesOnceTheWindowHasBeenQuietForASecond_andIsNotAScroll() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let recorder = SettleRecorder()
        let observer = TooltipScrollObserver(scrollViews: { [] }, layoutRoot: { root })
        observer.delegate = recorder
        observer.start()
        addTeardownBlock { observer.stop() }
        let settled = expectation(description: "settled")
        recorder.onSettle = { settled.fulfill() }
        let changedAt = CACurrentMediaTime()

        root.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)))

        wait(for: [settled], timeout: 3)
        XCTAssertGreaterThanOrEqual(CACurrentMediaTime() - changedAt, 1)
        XCTAssertEqual(recorder.settles, 1)
        XCTAssertEqual(recorder.moves, 0)
    }

    func testAnUnchangedWindow_orAStoppedObserver_neverSettles() {
        let unchanged = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let changed = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let recorder = SettleRecorder()
        let watching = TooltipScrollObserver(scrollViews: { [] }, layoutRoot: { unchanged })
        let stopped = TooltipScrollObserver(scrollViews: { [] }, layoutRoot: { changed })
        [watching, stopped].forEach {
            $0.delegate = recorder
            $0.start()
        }
        addTeardownBlock { watching.stop() }
        let settled = expectation(description: "no settle")
        settled.isInverted = true
        recorder.onSettle = { settled.fulfill() }

        stopped.stop()
        changed.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)))
        unchanged.setNeedsLayout()

        wait(for: [settled], timeout: 1.5)
    }

    func testAParkedTooltip_retriesOnceItsHostsLayoutSettles_withoutAScroll() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        var attempts = 0
        let retried = expectation(description: "retried after the layout settled")
        let recovery = TooltipRecoveryController(
            retryIntervals: [],
            scrollObserver: TooltipScrollObserver(scrollViews: { [] }, layoutRoot: { root })
        ) { completion in
            attempts += 1
            if attempts == 2 { retried.fulfill() }
            completion(attempts == 1 ? .notFound : nil)
        }
        addTeardownBlock { recovery.cancel() }

        recovery.attemptNow()
        root.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)))

        wait(for: [retried], timeout: 3)
        XCTAssertEqual(attempts, 2)
    }

    func testTheLayoutSignature_followsVisibleGeometryOnly() {
        let root = CALayer()
        root.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let child = CALayer()
        child.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        let hiddenContainer = CALayer()
        hiddenContainer.isHidden = true
        [child, hiddenContainer].forEach(root.addSublayer)
        let original = root.userpilotLayoutSignature()

        hiddenContainer.addSublayer(CALayer())
        XCTAssertEqual(root.userpilotLayoutSignature(), original, "Inside a hidden subtree")

        let changes = [
            GeometryChange(name: "moved", apply: { child.position.x += 5 }, undo: { child.position.x -= 5 }),
            GeometryChange(
                name: "resized", apply: { child.bounds.size.width = 20 }, undo: { child.bounds.size.width = 10 }
            ),
            GeometryChange(
                name: "scrolled", apply: { child.bounds.origin.y = 30 }, undo: { child.bounds.origin.y = 0 }
            ),
            GeometryChange(name: "faded", apply: { child.opacity = 0.5 }, undo: { child.opacity = 1 }),
            GeometryChange(name: "hidden", apply: { child.isHidden = true }, undo: { child.isHidden = false }),
            GeometryChange(
                name: "shown", apply: { hiddenContainer.isHidden = false }, undo: { hiddenContainer.isHidden = true }
            )
        ]
        for change in changes {
            change.apply()
            XCTAssertNotEqual(root.userpilotLayoutSignature(), original, change.name)
            change.undo()
            XCTAssertEqual(root.userpilotLayoutSignature(), original, "\(change.name), undone")
        }

        let added = CALayer()
        root.addSublayer(added)
        XCTAssertNotEqual(root.userpilotLayoutSignature(), original, "added")
        added.removeFromSuperlayer()
        XCTAssertEqual(root.userpilotLayoutSignature(), original, "removed")
    }
}

/// One edit to a layer's geometry, and the edit that restores it.
private struct GeometryChange {
    let name: String
    let apply: () -> Void
    let undo: () -> Void
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
