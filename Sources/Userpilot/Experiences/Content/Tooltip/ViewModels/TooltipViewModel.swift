//
//  TooltipViewModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Supplies a Flow tooltip segment's targeting, current-step presentation and step outcomes.
//  Owns tooltip preparation independently of carousel and slideout view models.
//  Every step reports through `FlowStepEvents` (see Flow Steps).
//

import UIKit

// MARK: - TooltipViewModel

/// Supplies a Flow tooltip segment's current step, its resolved theme, target configuration, and events.
/// The renderer drives this model on main, and renderer identity binds every event to the presentation
/// that produced it.
internal final class TooltipViewModel: BaseExperienceViewModel, ExperienceReporting {

    // MARK: Dependencies

    let experienceType = UserpilotExperienceType.flow
    var experienceID: Int? { flowContent?.id }

    private let themeHandler: ThemeHandling
    private(set) var flowContent: FlowContent?
    /// One merged theme per step in payload order; `tooltipTheme` maps the step showing now to its slot.
    private(set) var mergedTheme: [ThemeData] = []
    /// Called once by `onStart`: true when the segment can be shown as a tooltip.
    var bindData: ((Bool) -> Void)?

    var isRTL: Bool { (flowContent?.localeCode ?? "en").isRTL }

    /// The Flow walk segment this tooltip shows, set by `onStart`. Its steps report through
    /// `FlowStepEvents`, numbered by `position` among the Flow's `steps_count`; the run's next value
    /// is kept here after each outcome, like the carousel and slideout.
    private(set) var flowSegment: FlowSegment?

    /// The step whose step `seen` went out; each step is seen once, when it is revealed.
    private(set) var shownStepIndex: Int?

    /// Resolves the step's selector against the live view hierarchy.
    private let elementTargeting: ElementTargeting

    // MARK: Initialization

    /// Resolves only the services used by this renderer; no image or carousel state is created.
    override init(container: DIContainer) {
        themeHandler = container.resolve(ThemeHandling.self)
        elementTargeting = container.resolve(ElementTargeting.self)
        super.init(container: container)
    }

    /// Prepares the admitted Flow segment and its per-step themes without reporting engagement before the
    /// card is revealed. Only a `FlowSegment`'s tooltip projection can show a tooltip.
    func onStart() {
        let experience = experiencesPublisher.getActiveExperience(rendererID: rendererID)
        guard let content = experience?.asFlowContent(), let segment = experience?.flowSegment(),
              content.tooltipSteps != nil else {
            bindData?(false)
            return
        }
        flowContent = content
        flowSegment = segment
        mergedTheme = themeHandler.flowThemes(for: content, isFlowSegment: true)
        bindData?(true)
    }

    // MARK: Events

    /// Reports the segment's first step as `shown` once its card is revealed, even for a single step.
    ///
    /// Not delayed, unlike the carousel: the caller already waits for the card to be revealed.
    func onExperienceSeen() {
        reportStepShown()
    }

    /// Completes the step showing now as `advanced`; a `link` button (`isLink`) is `linked`, and only
    /// on the Flow's last step does it record `deepLink` for the publisher to open.
    func onExperienceCompleted(deepLink: String? = nil, isLink: Bool = false) {
        guard let flowSegment, let step = currentTooltipStep else { return }
        let outcome = isLink && isLastStepOfFlow
            ? FlowStepEvents.linked(flowSegment, step)
            : FlowStepEvents.advanced(flowSegment, step)
        if outcome.opensDeepLink { setCompletionDeepLink(deepLink) }
        reportFlowStep(outcome)
    }

    /// Reports the user's or the host app's close as `closed`; an SDK-driven close sends no Flow event,
    /// and backdrop taps do not close a Flow tooltip.
    func onTooltipDismissed(reason: TooltipDismissReason) {
        guard reason.dismissesStep, let flowSegment, let step = currentTooltipStep else { return }
        reportFlowStep(FlowStepEvents.closed(flowSegment, step))
    }

    /// Moves the segment to `index`. The tap completes the step it leaves as `advanced`; the next step
    /// is seen when it is revealed.
    ///
    /// A move to the step already showing, or out of range, does nothing, which keeps re-anchoring
    /// (after a scroll, a rotation, or a parked retry) from re-emitting events.
    func onTooltipStepChanged(_ index: Int) {
        guard index != currentStepIndex,
              tooltipSteps.indices.contains(index),
              let flowSegment,
              let previous = currentTooltipStep
        else { return }
        reportFlowStep(FlowStepEvents.advanced(flowSegment, previous))
        currentStepIndex = index
    }

    /// Sends the step's `mobile_content_error` with the contract issue for the target failure `error`, once
    /// per step. A failure that is not the target's sends nothing.
    ///
    /// - Parameters:
    ///   - error: Why the target could not be used; its `reason` picks the issue.
    ///   - attemptCount: Lookups made, for the log line only.
    ///   - elapsedMs: Time spent searching, for the log line only.
    /// - Returns: True when the error was sent, so the renderer runs the step's fallback.
    @discardableResult
    func onTargetNotFound(error: TargetResolutionError, attemptCount: Int, elapsedMs: Int) -> Bool {
        logger.info(
            "🎯 Tooltip target alert after %{public}@ attempts in %{public}@ms: %{public}@ (match_count %{public}@)",
            String(attemptCount), String(elapsedMs), error.reason, String(error.matchCount)
        )
        guard let flowSegment, let step = currentTooltipStep else { return false }
        return reportTargetError(flowSegment, step, reason: error.reason)
    }

    // MARK: Targeting

    /// The host to search for targets, the key window first; nil when no eligible window is showing.
    func admitTargetHost() -> ElementTargetHost? {
        elementTargeting.admitHost()
    }

    /// Resolves this tooltip's target against the live view hierarchy.
    ///
    /// Owns the logging so the view controller does not need a logger of its
    /// own, and so every failure is reported in one place with one vocabulary.
    /// Failure reasons are a fixed set of identifiers — never selector values or
    /// host-app text, which would be host content in a log.
    ///
    /// Main thread only: the resolution walks the live view hierarchy.
    ///
    /// Completion receives the resolved target, or why it could not be resolved.
    func resolveTarget(in host: ElementTargetHost,
                       completion: @escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void) {
        guard let selector else {
            logger.error("❌ Tooltip step carries no usable selector")
            completion(.failure(.invalidSelector))
            return
        }
        let startedAt = DispatchTime.now()
        elementTargeting.resolve(selector: selector, in: host) { [weak self] result in
            self?.logger.debug("🎯 Tooltip target search took %{public}@ms", Self.elapsedMs(since: startedAt))
            if case let .failure(error) = result {
                self?.logger.info("🎯 Tooltip target not resolved: %{public}@", error.reason)
            }
            completion(result)
        }
    }

    /// Whether the admitted screen is at its end, so a missing target can be reported. Only
    /// called after a search found nothing; logs its duration without host-app identifiers.
    func isScreenAtEnd(in host: ElementTargetHost, completion: @escaping (Bool) -> Void) {
        let startedAt = DispatchTime.now()
        elementTargeting.isScreenAtEnd(in: host) { [weak self] atEnd in
            self?.logger.debug("🎯 Tooltip screen-end check took %{public}@ms (at end: %{public}@)",
                               Self.elapsedMs(since: startedAt), String(atEnd))
            completion(atEnd)
        }
    }

    // MARK: Renderer Log Lines

    /// The renderer's lines, logged here so the controller needs no logger of its own.
    func logNotRenderable() {
        logger.error("❌ Tooltip content is not renderable as a tooltip; abandoning")
    }

    func logUnresolvable(afterReveal: Bool) {
        if afterReveal {
            logger.info("🎯 Tooltip step target is unresolvable after reveal; dismissing")
        } else {
            logger.info("🎯 Tooltip target is unresolvable; abandoning without dismissal")
        }
    }

    func logTargetLost() {
        logger.info("🎯 Tooltip target lost after reveal; dismissing")
    }

    func logRevealed(at placement: TooltipPlacement?, attemptCount: Int) {
        logger.info("🎯 Tooltip revealed at %{public}@ after %{public}@ attempts",
                    placement?.rawValue ?? "fallback", String(attemptCount))
    }

    /// Milliseconds since `startedAt`, to one decimal place.
    private static func elapsedMs(since startedAt: DispatchTime) -> String {
        let nanoseconds = DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds
        return String(format: "%.1f", Double(nanoseconds) / 1_000_000)
    }

    // MARK: Content

    /// Which step of the segment is showing, 0-based.
    ///
    /// Written only by `onTooltipStepChanged`, and by `onTooltipStepSkipped` for a fallback.
    private(set) var currentStepIndex = 0

    /// Steps that already sent their target error, so a new recovery cycle for the same step
    /// never sends a second one.
    private var reportedTargetStepIDs: Set<Int> = []

    /// The segment's steps in author order; empty until content is bound.
    var tooltipSteps: [Step] {
        flowContent?.tooltipSteps ?? []
    }
}

// MARK: - Flow Steps

/// In this file because the outcomes share the private `reportedTargetStepIDs` latch.
extension TooltipViewModel {

    /// Reports a step that is revealed after the segment's first: placing its card is its reveal,
    /// since the move to it sent only the previous step's completion.
    func onStepRevealed() {
        reportStepShown()
    }

    /// `skip_step`: moves past a failed step without events, since its error was its outcome.
    func onTooltipStepSkipped() {
        guard !isLastStepOfSegment else { return }
        currentStepIndex += 1
    }

    /// Sends a step's target error; true when it was sent, so the renderer runs the step's fallback.
    private func reportTargetError(_ segment: FlowSegment, _ step: Step, reason: String) -> Bool {
        guard let issue = FlowContentErrorEvent.issue(for: reason),
              reportedTargetStepIDs.insert(step.id).inserted else { return false }
        let outcome = FlowStepEvents.failed(segment, step, issue: issue)
        reportFlowStep(outcome)
        return !outcome.events.isEmpty
    }

    /// Hands the outcome's run and events to the publisher in one call, then fires its callbacks, so a host
    /// reacting inside a callback already finds the outcome published. An outcome without events reports nothing.
    private func reportFlowStep(_ outcome: FlowStepOutcome) {
        guard !outcome.events.isEmpty else { return }
        flowSegment?.run = outcome.run
        experiencesPublisher.publishFlowStepOutcome(outcome, rendererID: rendererID)
        notifyHost(outcome.callbacks)
    }

    /// Seen once per step, when its card is revealed.
    private func reportStepShown() {
        guard let flowSegment, !isCurrentStepShown, let step = currentTooltipStep else { return }
        shownStepIndex = currentStepIndex
        reportFlowStep(FlowStepEvents.shown(flowSegment, step))
    }
}
