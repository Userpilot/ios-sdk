//
//  TooltipTargetCoordinator.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns initial resolution, retry recovery, and geometry-driven re-resolution.
//  Before reveal, recoverable failures retry then park, and a found target reveals
//  only once two lookups agree on its position. After reveal, consecutive
//  failures consume the target-loss budget before ending the tooltip. Once the
//  ladder is spent, a failed search is reported as a target alert; a target that
//  is not found is reported only when the screen is at its end.

import UIKit

// MARK: - TooltipTargetCoordinator

/// Resolves a tooltip's target on main for the life of its presentation.
/// The renderer supplies a resolver bound to its admitted host; retries never select another host.
/// Recovery owns timed attempts before reveal; geometry changes and host settles drive re-resolution after reveal.
internal final class TooltipTargetCoordinator {

    /// Consecutive failed re-resolutions a visible tooltip tolerates before its target counts as lost.
    static let postRevealFailureBudget = 1

    /// Wait before a visible target that one re-match missed is checked again.
    static let postRevealRecheckDelay: TimeInterval = 1

    /// Re-reads a found target may take to hold still before it reveals at its latest position.
    private static let stillnessChecks =
        Int((Constants.Theme.tooltipStillnessTimeout / Constants.Theme.tooltipStillnessInterval).rounded())

    // MARK: Callbacks

    /// The target resolved. Carries its rect in the admitted window's coordinates, in points.
    var onResolved: ((CGRect) -> Void)?

    /// A previously visible target has gone for good.
    var onTargetLost: (() -> Void)?

    /// The target can never resolve — a selector that matches nothing by
    /// construction, or a layout that cannot be read at all.
    var onUnresolvable: (() -> Void)?

    /// A search after the retry ladder failed in a way worth an alert. Carries the
    /// failure, how many attempts were made, and how long they took in milliseconds.
    /// Can fire on every later search; the view model sends at most one alert per step.
    var onTargetNotFound: ((TargetResolutionError, Int, Int) -> Void)?

    /// An attempt before reveal found no target. Fires on every such attempt, so its handler must be idempotent.
    var onAttemptFailed: (() -> Void)?

    // MARK: Properties

    private let resolveTarget: (@escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void) -> Void
    /// Asks whether the screen is at its end before a `not_found` alert. Completes on main.
    private let isScreenAtEnd: (@escaping (Bool) -> Void) -> Void
    /// The admitted host's scroll views, watched from the first timed retry until the target resolves.
    private let scrollViews: () -> [UIScrollView]
    /// The admitted host window, whose layout is watched over the same span.
    private let layoutRoot: () -> UIView?
    /// Invalidates an outstanding reply or stillness re-read on stop, retarget, a newer read or a scroll.
    private var resolutionRevision = 0
    private var retryIntervals: [Int] = []

    private var recovery: TooltipRecoveryController?

    /// Re-places a visible card when the presentation's geometry changes.
    private let geometryTracker = TargetGeometryTracker()

    /// Re-matches a visible card once its host window settles after a scroll or layout change.
    private var postRevealObserver: TooltipScrollObserver?

    /// Whether the card is on screen. Switches the failure rules above.
    private var isRevealed = false

    private var isTrackingGeometry = false

    /// Consecutive failures since the card was revealed.
    private var consecutivePostRevealFailures = 0

    /// When resolution first started, for the not-found signal's elapsed time.
    private var startedAt: Date?

    /// Attempts made so far, exposed so the reveal can report a retry count.
    private(set) var attemptCount = 0

    /// Runs a stillness re-read, or a visible target's recheck, after its delay, on main.
    /// Tests replace it to re-read at once.
    var scheduleStillnessCheck: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: Initialization

    init(
        resolveTarget: @escaping (@escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void) -> Void,
        isScreenAtEnd: @escaping (@escaping (Bool) -> Void) -> Void,
        scrollViews: @escaping () -> [UIScrollView] = { [] },
        layoutRoot: @escaping () -> UIView? = { nil }
    ) {
        self.resolveTarget = resolveTarget
        self.isScreenAtEnd = isScreenAtEnd
        self.scrollViews = scrollViews
        self.layoutRoot = layoutRoot
    }

    // MARK: Driving

    /// Makes the first attempt.
    ///
    /// The renderer supplies the retry ladder after loading content; an empty one means no retries.
    func start(retryIntervals: [Int]) {
        self.retryIntervals = retryIntervals
        startedAt = Date()
        recovery = makeRecovery()
        recovery?.attemptNow()
    }

    /// Rebuilds recovery with the current retry inputs and failure callbacks.
    private func makeRecovery() -> TooltipRecoveryController {
        let controller = TooltipRecoveryController(
            retryIntervals: retryIntervals,
            scrollObserver: TooltipScrollObserver(scrollViews: scrollViews, layoutRoot: layoutRoot)
        ) { [weak self] completion in
            self?.resolve(completion: completion)
        }
        controller.onUnrecoverableFailure = { [weak self] _ in
            self?.onUnresolvable?()
        }
        controller.onSearchFailed = { [weak self] error, attempts in
            self?.searchFailed(error, attempts: attempts)
        }
        controller.onAttemptAbandoned = { [weak self] in
            self?.resolutionRevision += 1
        }
        return controller
    }

    /// A failed search after the ladder. A target that is not found is reported only when the
    /// screen is at its end, so the user has seen all of it; any other failure is reported now.
    /// A newer search, a stop or a retarget makes a pending screen-end answer stale.
    private func searchFailed(_ error: TargetResolutionError, attempts: Int) {
        let elapsed = startedAt.map { Int(Date().timeIntervalSince($0) * 1_000) } ?? 0
        guard case .notFound = error else {
            onTargetNotFound?(error, attempts, elapsed)
            return
        }
        let revision = resolutionRevision
        isScreenAtEnd { [weak self] atEnd in
            guard let self, atEnd, self.resolutionRevision == revision else { return }
            self.onTargetNotFound?(error, attempts, elapsed)
        }
    }

    /// Starts resolution for the newly selected step with its retry intervals.
    /// Stops the old recovery controller and resets per-step reveal and failure state.
    func retarget(retryIntervals: [Int]) {
        stop()
        isRevealed = false
        consecutivePostRevealFailures = 0
        attemptCount = 0
        start(retryIntervals: retryIntervals)
    }

    /// Retries after rotation while hidden. Once visible, bounds tracking owns
    /// re-resolution so rotation does not also consume recovery ladder entries.
    func handleRotation() {
        guard !isRevealed else { return }
        recovery?.attemptNow()
    }

    /// Records that the card is now visible, and starts watching its geometry and its host window.
    ///
    /// - Parameter container: the tooltip's backdrop, whose bounds changes are
    ///   the signal that the card needs re-placing.
    func beginTracking(in container: UIView) {
        isRevealed = true
        consecutivePostRevealFailures = 0

        guard !isTrackingGeometry else { return }
        isTrackingGeometry = true

        geometryTracker.onGeometryChanged = { [weak self] in
            self?.handlePostRevealChange()
        }
        geometryTracker.start(in: container)

        let observer = TooltipScrollObserver(scrollViews: scrollViews, layoutRoot: layoutRoot)
        observer.delegate = self
        observer.start()
        postRevealObserver = observer
    }

    /// Stops all target work. Idempotent, and required on every terminal path —
    /// otherwise a dismissed tooltip keeps walking the view hierarchy on a timer
    /// or sits parked on the scroll observer for the life of the process.
    func stop() {
        resolutionRevision += 1
        recovery?.cancel()
        geometryTracker.stop()
        postRevealObserver?.stop()
        postRevealObserver = nil
        isTrackingGeometry = false
    }

    // MARK: Resolution

    /// One resolution attempt. Before reveal, a found target must also hold still.
    ///
    /// Completion receives `nil` when the target resolved, otherwise the failure.
    private func resolve(completion: @escaping (TargetResolutionError?) -> Void) {
        attemptCount += 1
        resolutionRevision += 1
        let revision = resolutionRevision
        resolveTarget { [weak self] result in
            guard let self, self.resolutionRevision == revision else { return }
            guard case let .success(found) = result, !self.isRevealed else {
                self.finishAttempt(with: result, completion: completion)
                return
            }
            self.awaitStillTarget(found, revision: revision, checksLeft: Self.stillnessChecks) { [weak self] still in
                self?.finishAttempt(with: still, completion: completion)
            }
        }
    }

    private func finishAttempt(
        with result: Result<ResolvedTarget, TargetResolutionError>,
        completion: (TargetResolutionError?) -> Void
    ) {
        switch result {
        case let .success(target):
            onResolved?(target.rect)
            completion(nil)
        case let .failure(error):
            if !isRevealed { onAttemptFailed?() }
            completion(error)
        }
    }

    /// Re-reads a target found before reveal until two lookups a short interval apart agree, so the
    /// tooltip never reveals at a position the content is still scrolling or animating through.
    /// Completes with the failure when the target leaves meanwhile. A target still moving at the
    /// timeout, such as an auto-scrolling banner, reveals at its latest position. A stop, retarget
    /// or abandoned attempt makes the revision stale and ends the wait without completing.
    private func awaitStillTarget(
        _ latest: ResolvedTarget,
        revision: Int,
        checksLeft: Int,
        completion: @escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void
    ) {
        guard checksLeft > 0 else {
            completion(.success(latest))
            return
        }
        scheduleStillnessCheck(Constants.Theme.tooltipStillnessInterval) { [weak self] in
            guard let self, self.resolutionRevision == revision else { return }
            self.resolveTarget { [weak self] result in
                guard let self, self.resolutionRevision == revision else { return }
                let tolerance = Constants.Theme.tooltipStillnessTolerance
                guard case let .success(next) = result, !next.rect.userpilotIsNear(latest.rect, tolerance: tolerance)
                else {
                    completion(result)
                    return
                }
                self.awaitStillTarget(next, revision: revision, checksLeft: checksLeft - 1, completion: completion)
            }
        }
    }

    /// Re-match after a size change or a host settle; a delayed reply cannot reposition a stopped or
    /// retargeted card. A miss within the budget is checked once more, so a removed target is lost.
    private func handlePostRevealChange() {
        resolve { [weak self] error in
            guard let self else { return }
            guard error != nil else {
                self.consecutivePostRevealFailures = 0
                return
            }
            self.consecutivePostRevealFailures += 1
            guard self.consecutivePostRevealFailures > Self.postRevealFailureBudget else {
                self.recheckAfterMiss()
                return
            }
            self.stop()
            self.onTargetLost?()
        }
    }

    /// A newer re-match, a stop or a retarget makes the recheck stale.
    private func recheckAfterMiss() {
        let revision = resolutionRevision
        scheduleStillnessCheck(Self.postRevealRecheckDelay) { [weak self] in
            guard let self, self.resolutionRevision == revision else { return }
            self.handlePostRevealChange()
        }
    }
}

// MARK: - TooltipScrollDelegate

extension TooltipTargetCoordinator: TooltipScrollDelegate {

    /// The host settled while the card is visible, so its target may have moved, changed or gone.
    func scrollDidSettle() {
        handlePostRevealChange()
    }
}
