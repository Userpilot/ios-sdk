//
//  TooltipViewController+Paging.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Paging for a Flow tooltip segment: what the action button does, and how the
//  card and the target coordinator are re-pointed at the next step.
//
//  A separate file purely to keep `TooltipViewController.swift` under the
//  SwiftLint file-length limit. It is part of the same controller.
//
//  The whole segment is **one presentation**. Advancing rebinds the card and
//  restarts the coordinator against the next step's selector; it never dismisses
//  and re-presents. Which step is showing lives in the view model
//  (`currentStepIndex`); the controller keeps no index of its own. A revealed
//  overlay stays on screen while the next target resolves, fades out when that
//  target is not there at once, and pages past a failed step through its
//  fallback.
//

import UIKit

// MARK: - Paging

internal extension TooltipViewController {

    /// The segment's steps, in author order.
    var tooltipSteps: [Step] {
        viewModel.tooltipSteps
    }

    /// The card's action button advances the segment, or completes its last step.
    ///
    /// Index-based: the payload's `button_action` is an opaque string with no
    /// wire-level "advance" signal. A `nil` action is not a dead control — it
    /// advances, or completes on the final step, so the user is never stranded.
    ///
    /// **A deep link is followed only from the Flow's last step.** An intermediate step
    /// that navigated away would strand its own Flow. The segment's last step, or the
    /// Flow's last, closes the overlay and the publisher continues the walk or reloads.
    /// A step takes no action before it was seen.
    func handleAction(_ action: ButtonAction?) {
        guard !hasReachedTerminalState, canTakeUserAction else { return }

        guard viewModel.completesSegment else {
            advance(to: viewModel.currentStepIndex + 1)
            return
        }

        completeTooltip(deepLink: action?.deepLink, isLink: action?.isLink == true)
    }

    /// A target tap advances like the step's button, never inheriting the button's deep link.
    /// Internal access lets `applyStepConfiguration` wire it.
    func onTargetTapped() {
        handleAction(nil)
    }

    /// Moves the segment to `index`, its next step in the same presentation.
    ///
    /// Refuses going backwards or out of range. A second advance inside
    /// `advanceReentryWindow` is a double tap and is ignored, so a step is never
    /// skipped unseen: everything here is synchronous, so without it tap 2 would
    /// page 1 -> 2 before the user has read step 1. A timestamp rather
    /// than "wait for the next target to resolve", which would leave the button
    /// dead for as long as a step stays parked waiting for a scroll.
    func advance(to index: Int) {
        guard !hasReachedTerminalState,
              !viewModel.completesSegment,
              index > viewModel.currentStepIndex,
              index < tooltipSteps.count
        else { return }

        let now = Date()
        if let last = lastAdvanceAt, now.timeIntervalSince(last) < advanceReentryWindow {
            return
        }
        lastAdvanceAt = now

        // Stop the previous ladder before starting the next, or the segment leaks a
        // parked scroll observer per step for the life of the process.
        targetCoordinator.stop()

        viewModel.onTooltipStepChanged(index)
        showCurrentStep()
    }

    /// Swaps in the current step and starts resolving its target; a revealed overlay
    /// stays on screen meanwhile, still showing the previous step's card.
    func showCurrentStep() {
        let holdsOverlay = hasRevealed && !isParked
        if holdsOverlay {
            hasPendingStep = true
        } else {
            guard bindCurrentStep() else { return }

            // Hidden again until the next step's target resolves, and this is not
            // cosmetic. While a step is parked waiting for a scroll, a *visible*
            // wrapper keeps `ExperienceOverlayWindow.hitTest` claiming every touch, so
            // the scroll that would recover the target can never happen and the host
            // app is dead behind a keyhole still lit around the previous step's
            // element. `retarget()`'s first attempt is fully synchronous, so in the
            // common case this and the un-hide in `handleResolvedTarget` land in the
            // same runloop turn and nothing reaches the screen in between.
            wrapperView.isHidden = true
        }
        targetCoordinator.retarget(retryIntervals: retryIntervals)

        // `.layoutChanged`, not `.screenChanged`: the segment has not left its screen.
        // A held overlay announces its next card when that card is bound.
        guard !holdsOverlay else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: wrapperView.cardView)
    }

    /// Applies the current step's configuration and card. False when the step is gone.
    @discardableResult
    func bindCurrentStep(dimFadeDuration: TimeInterval = 0) -> Bool {
        hasPendingStep = false
        applyStepConfiguration(dimFadeDuration: dimFadeDuration)

        // `[safe:]` rather than a raw subscript even though `index` was just
        // range-checked: `currentStepIndex` is read back from the view model, and
        // `tooltipSteps` is backend data that a mid-tour content refresh can
        // shorten underneath us.
        guard let step = tooltipSteps[safe: viewModel.currentStepIndex] else { return false }
        bindCard(step: step)

        // Measure the new content *before* repositioning. `bindCard` swapped the
        // card's subviews but `cardView.reportedContentSize` is still the previous
        // step's, so the `targetRect` didSet would animate a 0.3s glide to a frame
        // sized for the old step and only then snap — a two-stage jump visible
        // whenever step heights differ.
        wrapperView.setNeedsLayout()
        wrapperView.layoutIfNeeded()
        return true
    }

    /// Pushes the current step's `presentation` block and theme into the view,
    /// then wires the target hotspot. A tap on the dim does nothing.
    ///
    /// Re-run on **every** advance, not just at bind. `presentation` is per-step,
    /// so a tour that kept step 0's values would place step 1 on step 0's side,
    /// keep step 0's target tap, and draw step 0's backdrop colour around step 1's
    /// card. The card's own content is already per-step via `bindCard`; the
    /// backdrop drawn around it has to agree with it.
    ///
    /// Lives here rather than in `TooltipViewController.swift` only because that
    /// file is at its SwiftLint `file_length` limit — it is part of the same
    /// controller, and `bindViewModel` calls it for step 0.
    func applyStepConfiguration(dimFadeDuration: TimeInterval = 0) {
        wrapperView.configure(
            presentation: viewModel.presentation,
            theme: viewModel.tooltipTheme,
            dimFadeDuration: dimFadeDuration
        )

        // Assigned unconditionally, **including the `nil`**. Wiring it only when
        // present would both miss a step-1-only hotspot — which for a step with no
        // close button is the only exit, so the user would be stranded — and
        // leave a step-0-only hotspot live on a later step, completing the tour
        // from a tap on an element that step never highlighted.
        wrapperView.backdropView.onTargetTapped = viewModel.presentation.hasTargetTapAction
            ? { [weak self] in self?.onTargetTapped() }
            : nil
    }

    /// A target that can never resolve.
    ///
    /// A revealed overlay closes as a lost target; before any reveal nothing was seen, so it is
    /// abandoned. Both paths share the `hasReachedTerminalState` latch, and neither sends an event.
    func handleUnresolvable() {
        viewModel.logUnresolvable(afterReveal: hasRevealed)
        if hasRevealed {
            dismissForTargetLost()
        } else {
            abandonPresentation()
        }
    }
}

// MARK: - Flow Segment

internal extension TooltipViewController {

    /// Taps on a step's card before it was seen come from the outgoing card and do nothing.
    var canTakeUserAction: Bool {
        viewModel.isCurrentStepShown
    }

    /// A Flow step's target error was reported. `skip_step` pages silently to the segment's next
    /// step while the overlay is parked; with no step left, or once `end_flow` or the Flow's last step
    /// ended the run, the hidden overlay closes and the publisher continues or reloads.
    func runFallback() {
        guard !hasReachedTerminalState else { return }
        guard !viewModel.isFlowRunEnded, !viewModel.isLastStepOfSegment else {
            abandonPresentation()
            return
        }
        targetCoordinator.stop()
        viewModel.onTooltipStepSkipped()
        showCurrentStep()
    }

    /// Fades a revealed Flow overlay out because the next step's target was not there at once, then
    /// hides it so the host can be scrolled to that target. Idempotent: the coordinator calls it on
    /// every failed attempt before reveal. A target that resolves on its first attempt is never parked.
    func park() {
        guard hasRevealed, !isParked, !hasReachedTerminalState else { return }
        isParked = true
        UIView.animate(
            withDuration: Constants.Theme.tooltipFlowFadeDuration,
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: { [weak self] in self?.wrapperView.alpha = 0 },
            completion: { [weak self] _ in
                guard let self, self.isParked else { return }
                self.wrapperView.isHidden = true
            }
        )
    }

    /// Binds a step the held overlay was still waiting for, its dim fading with the glide. Returns
    /// whether the overlay comes back from park: it is then placed at once, and fades back in.
    func prepareFlowReveal() -> Bool {
        let returnsFromPark = isParked
        if returnsFromPark { wrapperView.hasPositionedOnce = false }
        guard hasPendingStep else { return returnsFromPark }
        bindCurrentStep(dimFadeDuration: returnsFromPark ? 0 : Constants.Theme.tooltipFlowFadeDuration)
        UIAccessibility.post(notification: .layoutChanged, argument: wrapperView.cardView)
        return returnsFromPark
    }

    /// Fades a parked overlay back in at its new target.
    func fadeInFromPark() {
        isParked = false
        UIView.animate(
            withDuration: Constants.Theme.tooltipFlowFadeDuration,
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: { [weak self] in self?.wrapperView.alpha = 1 }
        )
    }
}
