//
//  ExperienceViewModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Manages a carousel or slideout's content, merged themes and engagement reporting, for standalone
//  content and for one modal or slideout step of a Flow walk.
//

import Foundation

/// Prepares flow content and reports engagement in the renderer's existing callback order.
/// UIKit callbacks own these calls; only completed dismissal releases the publisher's renderer.
internal final class ExperienceViewModel: BaseExperienceViewModel, ExperienceReporting {

    // MARK: - Properties

    let experienceType = UserpilotExperienceType.flow
    var experienceID: Int? { flowContent?.id }

    private let themeHandler: ThemeHandling
    let imageLoader: ImageLoading

    /// A mutable list of merged theme data for the carousel.
    private(set) var mergedTheme = [ThemeData]()
    var carouselTheme: [ExperienceTheme] {
        return mergedTheme.compactMap { $0.carousel }
    }
    var slideOutTheme: ExperienceTheme {
        return mergedTheme.first?.slideOut ?? ExperienceTheme()
    }

    /// Flow content to display.
    private(set) var flowContent: FlowContent?
    var slideOutContent: Step? {
        flowContent?.steps.first
    }

    /// Set when this renderer shows one step of a Flow walk; its steps then report through `FlowStepEvents`.
    private var flowSegment: FlowSegment?

    /// Whether this renderer shows a Flow step; only then does a slideout show progress.
    var isFlowSegment: Bool {
        flowSegment != nil
    }

    /// Visible position may move backward; engagement advances only beyond the furthest step.
    private(set) var currentStep = 0
    private var furthestStep = 0

    /// The first step's seen goes out once, on the first appearance.
    private var didSendSeenContentEvent = false

    /// closure to observe the binding state of the content
    var bindData: ((Bool) -> Void)?

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    override init(container: DIContainer) {
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.imageLoader = container.resolve(ImageLoading.self)
        super.init(container: container)
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the carousel content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        let experience = experiencesPublisher.getActiveExperience(rendererID: rendererID)
        guard let flowContent = experience?.asFlowContent() else {
            bindData?(false)
            return
        }

        self.flowContent = flowContent
        flowSegment = experience?.flowSegment()
        prepareThemes(for: flowContent)
        bindData?(canBindContent(flowContent))
    }

    /// Keeps one merged theme per step: the app theme when resolved, else the content's own themes.
    private func prepareThemes(for content: FlowContent) {
        mergedTheme.append(contentsOf: themeHandler.flowThemes(for: content, isFlowSegment: isFlowSegment))
    }

    /// Prevents binding incomplete backend content without changing renderer fallback behavior.
    private func canBindContent(_ content: FlowContent) -> Bool {
        guard !content.steps.isEmpty else { return false }
        switch content.type {
        case .carousel:
            return !carouselTheme.isEmpty
        case .slideout:
            return mergedTheme.first?.slideOut != nil
        case .tooltip:
            return content.tooltipSteps != nil
        case .flow:
            return false
        }
    }

    /// Resolves the content locale, retaining the English fallback for missing content.
    var isRTL: Bool {
        return (flowContent?.localeCode ?? "en").isRTL == true
    }

    /// Returns the total number of steps in the carousel.
    var carouselStepsCount: Int {
        return flowContent?.steps.count ?? 0
    }

    /// Steps the progress view draws: the whole Flow's `steps_count` for a Flow step, else this content's steps.
    var progressStepsCount: Int {
        flowSegment?.stepsCount ?? carouselStepsCount
    }

    /// Progress index for carousel `page`: a Flow step's `position - 1` kept inside its steps, else the page itself.
    func progressStepIndex(_ page: Int) -> Int {
        flowStepsProgress(page)?.index ?? page
    }

    /// A Flow step's place in its progress view for carousel `page`; nil outside a Flow.
    func flowStepsProgress(_ page: Int) -> FlowStepsProgress? {
        guard let flowSegment else { return nil }
        let position = flowContent?.steps[safe: page]?.position
        return FlowStepsProgress(stepsCount: flowSegment.stepsCount, stepIndex: position.map { $0 - 1 } ?? page)
    }

    // MARK: - Experience Event Handling

    /// Reports seen on the first appearance only; a later `viewDidAppear` reports nothing.
    func onExperienceSeen() {
        guard
            !didSendSeenContentEvent,
            let flowContent,
            let step = flowContent.steps.first
        else { return }
        didSendSeenContentEvent = true

        if let flowSegment {
            reportFlowStep(FlowStepEvents.shown(flowSegment, step))
            return
        }

        report(FlowContentEvents.opened(flowContent))
    }

    /**
     The last page's action button. Standalone content records `action`'s deep link and completes; a Flow step
     advances, or opens the link when it is the Flow's last step.
     */
    func onExperienceCompleted(_ action: ButtonAction) {
        if let flowSegment, let step = flowContent?.steps.first {
            reportFlowAction(flowSegment, step, action)
            return
        }
        setCompletionDeepLink(action.deepLink)
        guard let flowContent else { return }

        report(FlowContentEvents.completed(flowContent))
    }

    /**
     Handles the change of steps in the carousel. Only standalone content reports it; a Flow step is one page.
     
     - Parameter step: The current step number.
     */
    func onStepChanged(_ step: Int) {
        currentStep = step
        guard flowSegment == nil, step > furthestStep else { return }
        furthestStep = step

        guard let flowContent else { return }

        report(FlowContentEvents.paged(flowContent, page: step))
    }

    /// The user's or the host app's close. Standalone content reports the furthest step and the Flow dismissed; a
    /// Flow step reports through `FlowStepEvents.closed`, with the state from its own `dismiss_action`.
    /// Renderer teardown is reported separately.
    func onDismissStep() {
        if let flowSegment, let step = flowContent?.steps.first {
            reportFlowStep(FlowStepEvents.closed(flowSegment, step))
            return
        }
        guard let flowContent else { return }

        report(FlowContentEvents.dismissed(flowContent, furthestPage: furthestStep))
    }

    // MARK: - Engagement Reporting

    /// `link` reports like `next`; only the Flow's last step records the deep link before its events go out.
    private func reportFlowAction(_ segment: FlowSegment, _ step: Step, _ action: ButtonAction) {
        let outcome = action.isLink ? FlowStepEvents.linked(segment, step) : FlowStepEvents.advanced(segment, step)
        if outcome.opensDeepLink { setCompletionDeepLink(action.deepLink) }
        reportFlowStep(outcome)
    }

    /// Hands the outcome's run and events to the publisher in one call, then fires its callbacks, so a host
    /// reacting inside a callback already finds the outcome published. An outcome without events reports nothing.
    private func reportFlowStep(_ outcome: FlowStepOutcome) {
        guard !outcome.events.isEmpty, flowContent != nil else { return }
        flowSegment?.run = outcome.run
        experiencesPublisher.publishFlowStepOutcome(outcome, rendererID: rendererID)
        notifyHost(outcome.callbacks)
    }
}
