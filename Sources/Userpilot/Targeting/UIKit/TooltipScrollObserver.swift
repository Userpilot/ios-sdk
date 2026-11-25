//
//  TooltipScrollObserver.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Tells one waiting tooltip when the user scrolls its host window, and when the window settles.
//  Observes `contentOffset` on that window's scroll views, and its layout, only while the tooltip waits.
//

import UIKit

// MARK: - Observer

/// Main-thread callbacks for a waiting tooltip as the user scrolls and when the host window settles.
internal protocol TooltipScrollDelegate: AnyObject {

    /// Called on the main thread for each user-driven offset change.
    func scrollDidMove()

    /// Called on the main thread once scrolling or layout has come to rest, so a target that was below
    /// the fold, not yet added or hidden may now be on screen.
    func scrollDidSettle()
}

internal extension TooltipScrollDelegate {
    func scrollDidMove() {}
}

// MARK: - TooltipScrollObserver

/// Watches the scroll views and layout of one tooltip's host window between `start()` and `stop()`.
/// Main thread only.
///
/// A waiting target has not resolved, so its ancestor scroll views are not known: every visible scroll
/// view of the host window is observed, and the list is refreshed after each settle so one added later
/// is picked up. Only user-driven movement counts as a scroll (tracking, dragging or decelerating), so a
/// banner that scrolls itself does not pause the retry ladder. Scrolling and layout changes each push back
/// their own one-second timer, so a retry waits until the window stops changing; scrolling keeps its own
/// timer so a screen that never stops animating still recovers after a scroll. No delegate is assigned
/// and nothing is swizzled; `stop()` removes every observation, and so does releasing the observer.
internal final class TooltipScrollObserver {

    // MARK: Nested Types

    private enum Constants {
        /// How long scrolling or layout must stay at rest before a retry is attempted.
        ///
        /// Long enough for a bounce to settle, and short enough not to feel
        /// broken. It also collapses a flurry of small scrolls into one retry
        /// rather than re-walking the view tree for each.
        static let settleDelay: TimeInterval = 1
    }

    private struct Observation {
        weak var scrollView: UIScrollView?
        let token: NSKeyValueObservation
    }

    // MARK: Properties

    weak var delegate: TooltipScrollDelegate?

    private let scrollViews: () -> [UIScrollView]
    private let layoutObserver: TooltipLayoutObserver
    private var observations: [Observation] = []
    private var isObserving = false

    /// Settles once user scrolling has stopped for `settleDelay`.
    private let scrollQuiet = TooltipQuietTimer(delay: Constants.settleDelay)

    /// Settles once the window's layout has stopped changing for `settleDelay`.
    private let layoutQuiet = TooltipQuietTimer(delay: Constants.settleDelay)

    // MARK: Initialization

    /// - Parameters:
    ///   - scrollViews: the scroll views to watch, read on `start()` and after each settle.
    ///   - layoutRoot: the host window whose layout changes also settle; `nil` watches scrolling only.
    init(scrollViews: @escaping () -> [UIScrollView], layoutRoot: @escaping () -> UIView? = { nil }) {
        self.scrollViews = scrollViews
        layoutObserver = TooltipLayoutObserver(root: layoutRoot)
        layoutObserver.onChange = { [weak self] in
            self?.layoutQuiet.noteChange()
        }
        scrollQuiet.onQuiet = { [weak self] in
            self?.settle()
        }
        layoutQuiet.onQuiet = { [weak self] in
            self?.settle()
        }
    }

    // The tokens, timers and layout observer end their work as they are released.

    // MARK: Driving

    /// Starts observing, or picks up scroll views added since the last call. Idempotent.
    func start() {
        isObserving = true
        observeNewScrollViews()
        layoutObserver.start()
    }

    /// Removes every observation and drops a pending settle. Idempotent.
    func stop() {
        isObserving = false
        scrollQuiet.cancel()
        layoutQuiet.cancel()
        layoutObserver.stop()
        observations.forEach { $0.token.invalidate() }
        observations.removeAll()
    }

    private func observeNewScrollViews() {
        observations.removeAll { $0.scrollView == nil }
        for scrollView in scrollViews() where !observations.contains(where: { $0.scrollView === scrollView }) {
            let token = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
                guard scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating else { return }
                self?.recordMovement()
            }
            observations.append(Observation(scrollView: scrollView, token: token))
        }
    }

    // MARK: Settling

    private func recordMovement() {
        delegate?.scrollDidMove()
        scrollQuiet.noteChange()
    }

    /// Either timer settles both, so one quiet period makes one attempt.
    private func settle() {
        scrollQuiet.cancel()
        layoutQuiet.cancel()
        guard isObserving else { return }
        observeNewScrollViews()
        delegate?.scrollDidSettle()
    }
}

// MARK: - TooltipQuietTimer

/// Fires once changes have stopped for `delay`. Changes arrive as often as every frame, so one pending
/// check is kept and pushed back rather than one scheduled per change. Main thread only.
private final class TooltipQuietTimer {

    var onQuiet: (() -> Void)?

    private let delay: TimeInterval
    private var lastChangedAt: CFTimeInterval = 0
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    deinit {
        workItem?.cancel()
    }

    func noteChange() {
        lastChangedAt = CACurrentMediaTime()
        guard workItem == nil else { return }
        schedule(after: delay)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }

    private func schedule(after interval: TimeInterval) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.fireIfQuiet()
        }
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    private func fireIfQuiet() {
        workItem = nil
        let quiet = CACurrentMediaTime() - lastChangedAt
        guard quiet >= delay else {
            schedule(after: delay - quiet)
            return
        }
        onQuiet?()
    }
}
