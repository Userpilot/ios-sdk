//
//  SurveyViewModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This class is responsible for managing the state and interactions of the survey experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler, to
//  handle the experience flow, including data retrieval, theme merging, and
//  sending analytics events through socket requests.
//

import Foundation

/// Renderer-facing survey state and actions. UIKit owns presentation and dismissal completion.
protocol SurveyViewModeling: AnyObject {
    var surveyTheme: SurveyTheme? { get }
    var surveyContent: SurveyContent? { get }
    var currentStep: Int { get }
    var isRTL: Bool { get }
    var bindData: ((Bool) -> Void)? { get set }
    var closeSurvey: (() -> Void)? { get set }
    var bindNextSurveyStep: (() -> Void)? { get set }

    func onStart()
    func onExperienceSeen()
    func onExperienceDismissalCompleted()
    @discardableResult
    func showThankYouMessage() -> Bool
    func isAnyQuestionRequired() -> Bool
    func onSurveyCompleted()
    func onSurveyDismissed()
    func onSurveyListSubmitted(answersPayload: [Payload])
    func moveToNextSurveyStep(_ answer: Any?, _ answerPayload: Payload)
}

/// Prepares survey content, advances questions and reports answers for one renderer.
/// Renderer callbacks retain their existing main-thread delivery and dismissal ownership.
final class SurveyViewModel: SurveyViewModeling {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?
    private let experiencesPublisher: ExperiencesPublishing
    private let rendererID: UUID?
    private let themeHandler: ThemeHandling
    private let logger: Logging

    /// The merged theme data for the survey.
    private(set) var surveyTheme: SurveyTheme?

    /// Survey content to display.
    private(set) var surveyContent: SurveyContent?

    /// Track current survey step
    private(set) var currentStep = 0

    /// closure to observe the binding state of the content
    var bindData: ((Bool) -> Void)?
    var closeSurvey: (() -> Void)?
    var bindNextSurveyStep: (() -> Void)?
    private let surveyLogic: SurveyLogicHandling.Type = SurveyLogicHandler.self
    let submissionId: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.rendererID = experiencesPublisher.activeRendererID
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the survey content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            let surveyContent = experiencesPublisher.getActiveMobileContent(rendererID: rendererID)?.asSurveyContent()
        else {
            bindData?(false)
            return
        }

        // Setup content
        self.surveyContent = surveyContent
        if let lastModule = surveyContent.modules.last,
           lastModule.type == .completed,
           lastModule.metadata?.enabled == false {
            let listWithoutCompleteMessage = Array(surveyContent.modules.dropLast())
            self.surveyContent?.modules = listWithoutCompleteMessage
        }

        // Setup theme
        surveyTheme = themeHandler.surveyTheme(for: surveyContent)

        // Keep the original content check: removing a disabled thank-you module does not
        // change whether the backend supplied an empty survey.
        bindData?(!surveyContent.modules.isEmpty && surveyTheme != nil)
    }

    var isRTL: Bool {
        (surveyContent?.localeCode ?? "en").isRTL == true
    }

    /// Trigger thank you module
    @discardableResult
    func showThankYouMessage() -> Bool {
        guard let surveyContent, let surveyTheme else { return false }
        // Ask the flow whether a second step is owed, rather than re-deriving it from the content:
        // the flow is what the publisher acts on when this renderer dismisses, so a disagreement
        // between the two is what would strand the experience half-finished.
        if experiencesPublisher.hasNextFlowStep(rendererID: rendererID) {
            experiencesPublisher.showThankYouMessage(surveyContent, surveyTheme, submissionId, rendererID: rendererID)
            return true
        }
        onSurveyCompleted()
        return false
    }

    /// Notify the publisher after the survey view has finished dismissing.
    func onExperienceDismissalCompleted() {
        experiencesPublisher.experienceDidFinishDismissing(rendererID: rendererID)
    }

    /// Triggered the deep link from thank you message.
    private func onDeepLinkTriggered() {
        guard
            let deepLink = surveyContent?.thankYouDeepLink,
            let url = URL(string: deepLink)
        else { return }
        experiencesPublisher.triggerDeepLink(url: url)
    }

    func isAnyQuestionRequired() -> Bool {
        guard let surveyContent else { return false }
        return surveyContent.modules.contains { $0.isRequired == true }
    }

    // MARK: - Experience Event Handling

    func onExperienceSeen() {
        delay(0.3) { [weak self] in
            self?.onSurveyOpened()
        }
    }

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onSurveyOpened() {
        guard let surveyContent else { return }
        notifyExperienceState(.started, surveyContent: surveyContent)

        let eventExperienceSeen = ExperienceSurveySeenEvent(surveyId: surveyContent.id, submissionId: submissionId)
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSeen, rendererID: rendererID)

        if surveyContent.type == .step {
            onSurveyStepSeen()
        }
    }

    /// Reports completion with the configured thank-you navigation flag.
    func onSurveyCompleted() {
        guard let surveyContent else { return }
        publishSurveyCompleted(surveyContent, hasDeepLink: surveyContent.thankYouDeepLink != nil)
    }

    /// Shares completion reporting while callers distinguish a submitted action from a thank-you close.
    private func publishSurveyCompleted(_ surveyContent: SurveyContent, hasDeepLink: Bool) {
        notifyExperienceState(.completed, surveyContent: surveyContent)
        let event = ExperienceSurveyCompletedEvent(
            surveyId: surveyContent.id,
            submissionId: submissionId,
            hasDeepLinkContent: hasDeepLink
        )
        experiencesPublisher.publishInternalSDKEvent(event, rendererID: rendererID)
    }

    /// Closing a thank-you step completes the survey; closing a question dismisses it.
    func onSurveyDismissed() {
        guard
            let surveyContent,
            let surveyStep = getCurrentStepSurveyContent()
        else { return }
        if surveyStep.type == .completed {
            publishSurveyCompleted(surveyContent, hasDeepLink: false)
        } else {
            notifyExperienceState(.dismissed, surveyContent: surveyContent)

            let eventExperienceDismissed = ExperienceSurveyDismissedEvent(
                surveyId: surveyContent.id,
                submissionId: submissionId,
                moduleId: surveyContent.type == .list ? nil : surveyStep.id,
                type: surveyContent.type == .list ? nil : surveyStep.type.rawValue)
            experiencesPublisher.publishInternalSDKEvent(eventExperienceDismissed, rendererID: rendererID)
        }
    }

    private func onSurveyStepSeen() {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }

        notifyStepState(.started, surveyContent: surveyContent, surveyStep: surveyStep)

        let eventStepSeen = ExperienceSurveyStepSeenEvent(
            surveyId: surveyStep.id,
            submissionId: submissionId,
            moduleId: surveyStep.id,
            type: surveyStep.type.rawValue
        )
        experiencesPublisher.publishInternalSDKEvent(eventStepSeen, rendererID: rendererID)
    }

    /// Submits the list's answers before the renderer handles its thank-you or dismissal path.
    func onSurveyListSubmitted(answersPayload: [Payload]) {
        guard let surveyContent else { return }
        notifyExperienceState(.submitted, surveyContent: surveyContent)

        let eventContentSubmitted = ExperienceSurveySubmittedEvent(
            surveyId: surveyContent.id,
            submissionId: submissionId,
            feedback: answersPayload
        )
        experiencesPublisher.publishInternalSDKEvent(eventContentSubmitted, rendererID: rendererID)
    }

    private func onSurveyModuleSubmitted(_ answersPayload: Payload) {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }

        notifyStepState(.submitted, surveyContent: surveyContent, surveyStep: surveyStep)

        let eventStepSubmitted = ExperienceSurveyStepSubmittedEvent(
            surveyId: surveyContent.id,
            submissionId: submissionId,
            moduleId: surveyStep.id,
            type: surveyStep.type.rawValue,
            feedback: answersPayload?["value"]
        )
        experiencesPublisher.publishInternalSDKEvent(eventStepSubmitted, rendererID: rendererID)
    }

    private func onSurveyModuleSkipped() {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }

        notifyStepState(.skipped, surveyContent: surveyContent, surveyStep: surveyStep)

        let eventStepSkipped = ExperienceSurveyStepSkippedEvent(
            surveyId: surveyContent.id,
            submissionId: submissionId,
            moduleId: surveyStep.id,
            type: surveyStep.type.rawValue
        )
        experiencesPublisher.publishInternalSDKEvent(eventStepSkipped, rendererID: rendererID)
    }

    /** Logic region, fetch and understand Survey logic, notify screen with next survey step */
    private func isLastStep() -> Bool {
        guard let surveyContent else { return false }
        return currentStep == surveyContent.modules.count - 1
    }

    // Return current survey step content
    private func getCurrentStepSurveyContent() -> SurveyStep? {
        guard let surveyContent else { return nil }
        return surveyContent.modules[currentStep]
    }

    func moveToNextSurveyStep(
        _ answer: Any?,
        _ answerPayload: Payload
    ) {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        // We are on the last step, close the survey
        if isLastStep(), surveyStep.type == .completed {
            onDeepLinkTriggered()
            completeAndCloseSurvey()
            return
        }

        // Submit the answer payload in all cases while we are not on the thank you view
        if answer != nil {
            onSurveyModuleSubmitted(answerPayload)
        } else {
            onSurveyModuleSkipped()
        }

        // If we are on the last question, close the survey after submitting the answer
        if isLastStep() {
            completeAndCloseSurvey()
            return
        }

        // Get the next step index based on the logic handler
        let (nextStep, endSurvey) = surveyLogic.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: surveyContent.modules[currentStep].logic ?? [],
            answer: answer,
            surveySteps: surveyContent.modules
        )

        if endSurvey {
            completeAndCloseSurvey()
            return
        }

        // Determine whether to move to the next question or to a specified step
        currentStep = (nextStep == -1) ? (currentStep + 1) : nextStep

        // Update seen state for the next module
        if getCurrentStepSurveyContent()?.type != .completed {
            onSurveyStepSeen()
        }

        // Bind after reporting the next question as seen.
        bindNextSurveyStep?()
    }

    /// Reports completion before asking the renderer to dismiss; its completion releases ownership.
    private func completeAndCloseSurvey() {
        onSurveyCompleted()
        closeSurvey?()
    }

    // MARK: - Reporting

    /// Keep the delegate, log and subsequent event publication in their established order.
    private func notifyExperienceState(_ state: UserpilotExperienceState, surveyContent: SurveyContent) {
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .survey,
            experienceId: NSNumber(value: surveyContent.id),
            experienceState: state
        )
        logExperience(state: state.rawValueString, experienceId: surveyContent.id)
    }

    private func notifyStepState(
        _ state: UserpilotExperienceState,
        surveyContent: SurveyContent,
        surveyStep: SurveyStep
    ) {
        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: .survey,
            experienceId: NSNumber(value: surveyContent.id),
            stepId: NSNumber(value: surveyStep.id),
            stepState: state,
            step: nil,
            totalSteps: nil
        )
        logStep(state: state.rawValueString, experienceId: surveyContent.id, stepId: surveyStep.id)
    }

    // MARK: - Logging

    private func logExperience(
        state: String,
        experienceId: Int
    ) {
        logger.info(
            "🌠 Userpilot experience -> type: Survey, experienceId: %{public}@, state: %{public}@",
            String(experienceId),
            state
        )
    }

    private func logStep(
        state: String,
        experienceId: Int,
        stepId: Int
    ) {
        logger.info(
            // swiftlint:disable:next line_length
            "🌠 Userpilot experience step -> type: %{public}@, experienceId: %{public}@, state: %{public}@, stepId: %{public}@",
            UserpilotExperienceType.survey.rawValueString,
            String(experienceId),
            state,
            String(stepId)
        )
    }
}
