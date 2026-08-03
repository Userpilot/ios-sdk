//
//  ExperienceViewModel.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing the state and interactions of the carousel experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler,
//  and storage to handle the experience flow, including data retrieval, theme merging, and
//  sending analytics events through socket requests.
//

import Foundation

// swiftlint:disable line_length

internal class ExperienceViewModel {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?
    private let experiencesPublisher: ExperiencesPublishing
    private let themeHandler: ThemeHandling
    private let storage: DataStoring
    private let logger: Logging
    let imageLoader: ImageLoading

    /// A mutable list of merged theme data for the carousel.
    private var mergedTheme = [ThemeData]()
    // Computed property for `carouselTheme`
    var carouselTheme: [ExperienceTheme] {
        return mergedTheme.compactMap { $0.carousel }
    }
    // Computed property for `slideOutTheme`
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

    /// Decides whether Liquid Glass may be used by the views this view model drives.
    /// Exposed for the view layer the same way `imageLoader` is.
    let glassResolver: GlassCapabilityResolving

    /// How centre dialogs animate, from `Config.dialogAnimation(_:)`.
    let dialogAnimation: Userpilot.DialogAnimation

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.storage = container.resolve(DataStoring.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.imageLoader = container.resolve(ImageLoading.self)
        self.glassResolver = container.resolve(GlassCapabilityResolving.self)
        self.dialogAnimation = container.resolve(Userpilot.Config.self).dialogAnimationType
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the carousel content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            let flowContent = experiencesPublisher.getActiveMobileContent()?.asFlowContent()
        else {
            bindData?(false)
            return
        }

        // Setup content
        self.flowContent = flowContent

        // Setup theme
        let baseTheme = themeHandler.getThemeById(flowContent.baseThemeId)
        flowContent.steps.forEach { step in
            mergedTheme.append(
                themeHandler.mergeExperienceThemes(
                    baseTheme,
                    flowContent.mobileTheme.themeData,
                    step.mobileTheme
                )
            )
        }

        // Handle safe area region in case there is an issue with the data
        var shouldBindCarousel = true
        if flowContent.steps.isEmpty ||
            (flowContent.type == .carousel && carouselTheme.isEmpty) ||
            (flowContent.type == .slideout &&
             (mergedTheme.isEmpty || mergedTheme.first?.slideOut == nil)) {
            shouldBindCarousel = false
        }

        // Bind data
        bindData?(shouldBindCarousel)
    }

    /// Return wither the content is RTL
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

        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            experienceState: .started
        )
        logExperience(state: UserpilotExperienceState.started.rawValueString, experienceId: flowContent.id)

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            stepId: NSNumber(value: step.id),
            stepState: .started,
            step: 1,
            totalSteps: NSNumber(value: flowContent.steps.count)
        )
        logStep(
            state: UserpilotExperienceState.started.rawValueString,
            experienceId: flowContent.id,
            stepId: step.id,
            step: 1,
            totalSteps: flowContent.steps.count
        )

        let eventExperienceSeen = ExperienceFlowSeenEvent(flowId: flowContent.id)
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSeen)

        let eventStepSeen = ExperienceFlowStepSeenEvent(flowId: flowContent.id, stepId: step.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepSeen)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onExperienceCompleted() {
        guard
            let flowContent,
            let step = flowContent.steps.last
        else { return }

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            stepId: NSNumber(value: step.id),
            stepState: .completed,
            step: NSNumber(value: flowContent.steps.count),
            totalSteps: NSNumber(value: flowContent.steps.count)
        )
        logStep(
            state: UserpilotExperienceState.completed.rawValueString,
            experienceId: flowContent.id,
            stepId: step.id,
            step: flowContent.steps.count,
            totalSteps: flowContent.steps.count
        )

        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            experienceState: .completed
        )
        logExperience(state: UserpilotExperienceState.completed.rawValueString, experienceId: flowContent.id)

        let hasDeepLink = !(step.buttonAction?.deepLink?.isEmpty ?? true)

        let eventStepCompleted = ExperienceFlowStepCompletedEvent(
            flowId: flowContent.id,
            stepId: step.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepCompleted)

        let eventContentCompleted = ExperienceFlowCompletedEvent(
            flowId: flowContent.id,
            hasDeepLinkContent: hasDeepLink)
        experiencesPublisher.publishInternalSDKEvent(eventContentCompleted)
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

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            stepId: NSNumber(value: currentStep.id),
            stepState: .completed,
            step: NSNumber(value: step),
            totalSteps: NSNumber(value: flowContent.steps.count)
        )
        logStep(
            state: UserpilotExperienceState.completed.rawValueString,
            experienceId: flowContent.id,
            stepId: currentStep.id,
            step: step,
            totalSteps: flowContent.steps.count
        )

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            stepId: NSNumber(value: currentStep.id),
            stepState: .started,
            step: NSNumber(value: step + 1),
            totalSteps: NSNumber(value: flowContent.steps.count)
        )
        logStep(
            state: UserpilotExperienceState.started.rawValueString,
            experienceId: flowContent.id,
            stepId: currentStep.id,
            step: step + 1,
            totalSteps: flowContent.steps.count
        )

        let eventStepCompleted = ExperienceFlowStepCompletedEvent(
            flowId: flowContent.id,
            stepId: oldStep.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepCompleted)

        let eventStepSeen = ExperienceFlowStepSeenEvent(
            flowId: flowContent.id,
            stepId: currentStep.id)
        experiencesPublisher.publishInternalSDKEvent(eventStepSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
     
     - Parameter step: The step number that was dismissed.
     */
    func onDismissStep() {
        guard
            let flowContent,
            let step = flowContent.steps[safe: lastStep]
        else { return }

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            stepId: NSNumber(value: step.id),
            stepState: .dismissed,
            step: NSNumber(value: lastStep + 1),
            totalSteps: NSNumber(value: flowContent.steps.count)
        )
        logStep(
            state: UserpilotExperienceState.dismissed.rawValueString,
            experienceId: flowContent.id,
            stepId: step.id,
            step: lastStep + 1,
            totalSteps: flowContent.steps.count
        )

        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .flow,
            experienceId: NSNumber(value: flowContent.id),
            experienceState: .dismissed
        )
        logExperience(state: UserpilotExperienceState.dismissed.rawValueString, experienceId: flowContent.id)

        let eventExperienceDismissed = ExperienceFlowDismissedEvent(
            flowId: flowContent.id,
            stepId: step.id)
        experiencesPublisher.publishInternalSDKEvent(eventExperienceDismissed)
    }

    /// Notify the publisher after the experience view has finished dismissing.
    func onExperienceDismissalCompleted() {
        experiencesPublisher.experienceDidFinishDismissing()
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

}

// MARK: - Logging

// Extracted into an extension rather than kept in the type body: these are pure emit-only
// helpers that hold no state, and the type was already at the `type_body_length` limit.
private extension ExperienceViewModel {

    func logExperience(
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

    func logStep(
        state: String,
        experienceId: Int,
        stepId: Int,
        step: Int,
        totalSteps: Int
    ) {
        logger.info(
            "🌠 Userpilot experience step -> type: Flow, experienceId: %{public}@, state: %{public}@, stepId: %{public}@, step: %{public}@, totalSteps: %{public}@",
            String(experienceId),
            state,
            String(stepId),
            String(step),
            String(totalSteps)
        )
    }
}

// swiftlint:enable line_length
