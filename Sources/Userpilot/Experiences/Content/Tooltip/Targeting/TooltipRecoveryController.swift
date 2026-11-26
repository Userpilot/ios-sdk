//
//  TooltipRecoveryController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Attempts target resolution with a retry ladder, then parks recoverable
//  failures until the host window stops scrolling and laying out. Exhaustion is not a dismissal deadline;
//  fatal failures end recovery. The waiting tooltip remains non-blocking.
//  Nothing runs while the user scrolls: a scroll cancels the pending retry and
//  any read in flight, and the next settle makes the attempt, after which the
//  ladder resumes.

import UIKit

// MARK: - TooltipRecoveryController

/// Drives repeated target-resolution attempts on main for one recovery cycle.
/// Cancellation stops the timer and scroll subscription; it does not dismiss UI or publish engagement.
internal final class TooltipRecoveryController {

    // MARK: Nested Types

    /// One resolution attempt.
    ///
    /// Completion receives `nil` when the target resolved, or the failure to act on.
    typealias Attempt = (@escaping (TargetResolutionError?) -> Void) -> Void

    // MARK: Properties

    /// Called when a failure can never be recovered from, so the caller can give
    /// up rather than park forever.
    var onUnrecoverableFailure: ((TargetResolutionError) -> Void)?

    /// Called for every failed search once the ladder is spent: its last search and each
    /// later one. Carries the failure and the attempt count. The caller decides whether it
    /// is an alert; the view model sends at most one per step.
    var onSearchFailed: ((TargetResolutionError, Int) -> Void)?

    /// Called when a scroll abandons the read in flight, so the caller can drop its reply.
    var onAttemptAbandoned: (() -> Void)?

    private let attempt: Attempt
    private let scrollObserver: TooltipScrollObserver

    /// Remaining ladder intervals, consumed from the front.
    private var remainingIntervals: [Int]

    /// How many attempts have been made, reported with the not-found signal.
    private(set) var attemptCount = 0

    /// Pending ladder retry, so it can be cancelled on teardown.
    private var pendingRetry: DispatchWorkItem?

    /// Whether the ladder is spent and we are waiting on a scroll.
    private var isParked = false
    private var isCancelled = false
    private var isResolving = false

    /// Whether a scroll interrupted the ladder, so the next settle makes the attempt.
    private var isWaitingForSettle = false

    /// Whether `scrollObserver` is running for this recovery.
    private var isObservingScroll = false

    /// Identifies the read in flight, so the reply to an abandoned one is ignored.
    private var attemptGeneration = 0

    // MARK: Initialization

    /// - Parameters:
    ///   - retryIntervals: the ladder, in milliseconds. An explicitly empty
    ///     array means no timed retries — the author asked to fail straight to
    ///     the parked state.
    ///   - scrollObserver: source of scroll notifications, observing from the first timed retry until recovery ends.
    ///   - attempt: performs one resolution.
    init(
        retryIntervals: [Int],
        scrollObserver: TooltipScrollObserver = TooltipScrollObserver(scrollViews: { [] }),
        attempt: @escaping Attempt
    ) {
        self.remainingIntervals = retryIntervals
        self.scrollObserver = scrollObserver
        self.attempt = attempt
        scrollObserver.delegate = self
    }

    deinit {
        // Only the timer needs cancelling: this controller owns the scroll observer,
        // whose observations end when it is released.
        pendingRetry?.cancel()
    }

    // MARK: Driving

    /// Makes an attempt now, and schedules recovery if it fails.
    ///
    /// Main thread only: resolution walks the live view hierarchy.
    ///
    /// Concurrent signals share the pending read; cancellation ignores its eventual completion.
    func attemptNow() {
        guard !isCancelled, !isResolving else { return }
        pendingRetry?.cancel()
        pendingRetry = nil
        isWaitingForSettle = false
        attemptCount += 1
        isResolving = true
        attemptGeneration += 1
        let generation = attemptGeneration
        attempt { [weak self] error in
            guard let self, !self.isCancelled, self.attemptGeneration == generation else { return }
            self.isResolving = false
            guard let error else { self.stopRecovery(); return }
            guard error.isRetryable else {
                self.stopRecovery()
                self.onUnrecoverableFailure?(error)
                return
            }
            self.scheduleNext(after: error)
        }
    }

    /// Cancels every pending retry and stops listening for scrolls.
    ///
    /// Every terminal path must call this — a dismissed tooltip that kept
    /// retrying would walk the view hierarchy on a timer for the life of the
    /// process.
    func cancel() {
        isCancelled = true
        stopRecovery()
    }

    // MARK: Scheduling

    /// Takes the next rung of the ladder, or parks when it is spent.
    private func scheduleNext(after error: TargetResolutionError) {
        guard !remainingIntervals.isEmpty else {
            park(after: error)
            return
        }

        let delayMilliseconds = remainingIntervals.removeFirst()
        observeScroll()
        let workItem = DispatchWorkItem { [weak self] in
            self?.attemptNow()
        }
        pendingRetry = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(delayMilliseconds),
            execute: workItem
        )
    }

    /// Stops the timer and waits for the user to scroll.
    ///
    /// Only for failures that a scroll can actually fix — the target is below
    /// the fold, or two candidates are momentarily indistinguishable. A failure
    /// that scrolling cannot help (no readable layout at all) has no event to
    /// wait for, so parking on it would wait forever; it is reported instead.
    private func park(after error: TargetResolutionError) {
        // Reported before the recoverability gate below, so a failure that then
        // gives up still leaves telemetry: a tooltip that vanishes with none at all
        // is the hardest kind to diagnose.
        onSearchFailed?(error, attemptCount)

        guard !isCancelled else { return }
        guard error.isRecoverable else {
            stopRecovery()
            onUnrecoverableFailure?(error)
            return
        }

        guard !isParked else { return }
        isParked = true
        observeScroll()
    }

    /// Starts the observer, or refreshes its scroll views when it is already running,
    /// so one the host added since the last rung is watched too.
    private func observeScroll() {
        isObservingScroll = true
        scrollObserver.start()
    }

    private func stopRecovery() {
        pendingRetry?.cancel()
        pendingRetry = nil
        isParked = false
        isWaitingForSettle = false
        if isObservingScroll {
            isObservingScroll = false
            scrollObserver.stop()
        }
    }
}

// MARK: - TooltipScrollDelegate

extension TooltipRecoveryController: TooltipScrollDelegate {

    /// The window stopped scrolling and laying out, so the target may now be on screen.
    ///
    /// A failure here re-parks rather than escalating: the user may simply not
    /// have scrolled far enough yet, and there is no budget to run out of.
    func scrollDidSettle() {
        guard isParked || isWaitingForSettle else { return }
        attemptNow()
    }

    /// The user is scrolling, so a read now would see the target mid-scroll. The pending retry and
    /// any read in flight wait for the settle instead; a later scroll while waiting changes nothing.
    func scrollDidMove() {
        guard !isCancelled, !isParked, !isWaitingForSettle else { return }
        pendingRetry?.cancel()
        pendingRetry = nil
        if isResolving {
            isResolving = false
            attemptGeneration += 1
            onAttemptAbandoned?()
        }
        isWaitingForSettle = true
    }
}
