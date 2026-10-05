//
//  ExperienceViewModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This class is responsible for managing the state and interactions of the carousel experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler,
//  and storage to handle the experience flow, including data retrieval, theme merging, and
//  sending analytics events through socket requests.
//

import Foundation

/// Flow state and lifecycle actions consumed by carousel and slide-out renderers.
/// UIKit callbacks own these calls; only completed dismissal releases the publisher's renderer.
protocol ExperienceViewModeling: AnyObject {
    var imageLoader: ImageLoading { get }
    var carouselTheme: [ExperienceTheme] { get }
    var slideOutTheme: ExperienceTheme { get }
    var flowContent: FlowContent? { get }
    var slideOutContent: Step? { get }
    var currentStep: Int { get }
    var bindData: ((Bool) -> Void)? { get set }
    var isRTL: Bool { get }
    var carouselStepsCount: Int { get }

    func onStart()
    func onExperienceSeen()
    func onExperienceCompleted()
    func onStepChanged(_ step: Int)
    func onDismissStep()
    func onDeepLinkTriggered()
    func onExperienceDismissalCompleted()
}

/// Prepares flow content and reports engagement in the renderer's existing callback order.
internal class ExperienceViewModel: ExperienceViewModeling {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?
    private let experiencesPublisher: ExperiencesPublishing
    private let rendererID: UUID?
    private let themeHandler: ThemeHandling
    private let storage: DataStoring
    private let logger: Logging
    let imageLoader: ImageLoading

    /// A mutable list of merged theme data for the carousel.
    private var mergedTheme = [ThemeData]()
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

    /// Track current & last step user achieved - used in carousel content
    private(set) var currentStep = 0
    private var lastStep = 0

    /// closure to observe the binding state of the content
    var bindData: ((Bool) -> Void)?

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.rendererID = experiencesPublisher.activeRendererID
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.storage = container.resolve(DataStoring.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.imageLoader = container.resolve(ImageLoading.self)
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the carousel content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            let flowContent = experiencesPublisher.getActiveMobileContent(rendererID: rendererID)?.asFlowContent()
        else {
            bindData?(false)
            return
        }

        self.flowContent = flowContent
        prepareThemes(for: flowContent)
        bindData?(canBindContent(flowContent))
    }

    /// Keeps one merged theme per step: the app theme when resolved, else the content's own themes.
    private func prepareThemes(for content: FlowContent) {
        mergedTheme.append(contentsOf: themeHandler.flowThemes(for: content))
    }

    /// Prevents binding incomplete backend content without changing renderer fallback behavior.
    private func canBindContent(_ content: FlowContent) -> Bool {
        guard !content.steps.isEmpty else { return false }
        switch content.type {
        case .carousel:
            return !carouselTheme.isEmpty
        case .slideout:
            return mergedTheme.first?.slideOut != nil
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

    // MARK: - Experience Event Handling

    func onExperienceSeen() {
        delay(0.3) { [weak self] in
            self?.onExperienceOpened()
        }
    }
    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onExperienceOpened() {
        guard
            let flowContent,
            let step = flowContent.steps.first
        else { return }

        notifyExperienceState(.started, content: flowContent)

        notifyStepState(.started, stepId: step.id, step: 1, content: flowContent)

        let eventExperienceSeen = ExperienceFlowSeenEvent(flowId: flowContent.id)
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSeen, rendererID: rendererID)

        let eventStepSeen = ExperienceFlowStepSeenEvent(flowId: flowContent.id, stepId: step.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepSeen, rendererID: rendererID)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onExperienceCompleted() {
        guard
            let flowContent,
            let step = flowContent.steps.last
        else { return }

        notifyStepState(.completed, stepId: step.id, step: flowContent.steps.count, content: flowContent)

        notifyExperienceState(.completed, content: flowContent)

        let hasDeepLink = !(step.buttonAction?.deepLink?.isEmpty ?? true)

        let eventStepCompleted = ExperienceFlowStepCompletedEvent(
            flowId: flowContent.id,
            stepId: step.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepCompleted, rendererID: rendererID)

        let eventContentCompleted = ExperienceFlowCompletedEvent(
            flowId: flowContent.id,
            hasDeepLinkContent: hasDeepLink)
        experiencesPublisher.publishInternalSDKEvent(eventContentCompleted, rendererID: rendererID)
    }

    /**
     Handles the change of steps in the carousel.
     
     - Parameter step: The current step number.
     */
    func onStepChanged(_ step: Int) {
        currentStep = step
        guard step > lastStep else { return }
        lastStep = step

        guard
            let flowContent,
            let currentStep = flowContent.steps[safe: step],
            let oldStep = flowContent.steps[safe: step - 1]
        else { return }

        // Preserve the existing delegate/log ID; the completion event below uses the outgoing step.
        notifyStepState(.completed, stepId: currentStep.id, step: step, content: flowContent)

        notifyStepState(.started, stepId: currentStep.id, step: step + 1, content: flowContent)

        let eventStepCompleted = ExperienceFlowStepCompletedEvent(
            flowId: flowContent.id,
            stepId: oldStep.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepCompleted, rendererID: rendererID)

        let eventStepSeen = ExperienceFlowStepSeenEvent(
            flowId: flowContent.id,
            stepId: currentStep.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepSeen, rendererID: rendererID)
    }

    /// Reports the furthest reached step as dismissed; renderer teardown is reported separately.
    func onDismissStep() {
        guard
            let flowContent,
            let step = flowContent.steps[safe: lastStep]
        else { return }

        notifyStepState(.dismissed, stepId: step.id, step: lastStep + 1, content: flowContent)

        notifyExperienceState(.dismissed, content: flowContent)

        let eventExperienceDismissed = ExperienceFlowDismissedEvent(
            flowId: flowContent.id,
            stepId: step.id)
        experiencesPublisher.publishInternalSDKEvent(eventExperienceDismissed, rendererID: rendererID)
    }

    // MARK: - Deep Link Handling

    /**
     Handles navigation to a deep link specified in the last step of the carousel.
     If a deep link exists, the navigation delegate triggers the navigation action.
     */
    func onDeepLinkTriggered() {
        guard
            let deepLink = flowContent?.steps.last?.buttonAction?.deepLink,
            let url = URL(string: deepLink)
        else { return }
        experiencesPublisher.triggerDeepLink(url: url)
    }

    // MARK: - Engagement Reporting

    /// Notifies the host before logging; callers publish socket events in their existing order.
    private func notifyExperienceState(_ state: UserpilotExperienceState, content: FlowContent) {
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: content.id),
            experienceState: state
        )
        logExperience(state: state.rawValueString, experienceId: content.id)
    }

    /// Keeps delegate arguments and their matching log together without changing event delivery.
    private func notifyStepState(
        _ state: UserpilotExperienceState,
        stepId: Int,
        step: Int,
        content: FlowContent
    ) {
        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: content.id),
            stepId: NSNumber(value: stepId),
            stepState: state,
            step: NSNumber(value: step),
            totalSteps: NSNumber(value: content.steps.count)
        )
        logStep(
            state: state.rawValueString,
            experienceId: content.id,
            stepId: stepId,
            step: step,
            totalSteps: content.steps.count
        )
    }

    // MARK: - Logging

    private func logExperience(
        state: String,
        experienceId: Int
    ) {
        logger.info(
            "🌠 Userpilot experience -> type: %{public}@, experienceId: %{public}@, state: %{public}@",
            UserpilotExperienceType.flow.rawValueString,
            String(experienceId),
            state
        )
    }

    private func logStep(
        state: String,
        experienceId: Int,
        stepId: Int,
        step: Int,
        totalSteps: Int
    ) {
        // swiftlint:disable line_length
        logger.info(
            "🌠 Userpilot experience step -> type: Flow, experienceId: %{public}@, state: %{public}@, stepId: %{public}@, step: %{public}@, totalSteps: %{public}@",
            String(experienceId),
            state,
            String(stepId),
            String(step),
            String(totalSteps)
        )
        // swiftlint:enable line_length
    }
}

extension ExperienceViewModel {
    /// Notify the publisher after the experience view has finished dismissing.
    func onExperienceDismissalCompleted() {
        experiencesPublisher.experienceDidFinishDismissing(rendererID: rendererID)
    }
}
