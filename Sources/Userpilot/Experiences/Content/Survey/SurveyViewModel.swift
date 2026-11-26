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

/// Prepares survey content, advances questions and reports answers for one renderer.
/// Renderer callbacks retain their existing main-thread delivery and dismissal ownership.
final class SurveyViewModel: BaseExperienceViewModel, ExperienceReporting {

    // MARK: - Properties

    let experienceType = UserpilotExperienceType.survey
    var experienceID: Int? { surveyContent?.id }

    private let themeHandler: ThemeHandling

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
    private var didSendSeenContentEvent = false

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    override init(container: DIContainer) {
        self.themeHandler = container.resolve(ThemeHandling.self)
        super.init(container: container)
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the survey content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            let surveyContent = experiencesPublisher.getActiveExperience(rendererID: rendererID)?.asSurveyContent()
        else {
            bindData?(false)
            return
        }

        prepareContent(surveyContent)
        prepareTheme(for: surveyContent)

        // A survey whose only module is a disabled thank-you has nothing left to render.
        bindData?(self.surveyContent?.modules.isEmpty == false && surveyTheme != nil)
    }

    /// Only the terminal thank-you module can be omitted; questions retain their original order.
    private func prepareContent(_ content: SurveyContent) {
        surveyContent = content
        if let lastModule = content.modules.last,
           lastModule.type == .completed,
           lastModule.metadata?.enabled == false {
            surveyContent?.modules = Array(content.modules.dropLast())
        }
    }

    /// A resolved app theme wins; otherwise the survey override falls back to the cached base theme.
    private func prepareTheme(for content: SurveyContent) {
        surveyTheme = themeHandler.surveyTheme(for: content)
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

    /// Records the thank-you action's link before the renderer starts closing.
    private func setCompletionDeepLink() {
        setCompletionDeepLink(surveyContent?.thankYouDeepLink)
    }

    func isAnyQuestionRequired() -> Bool {
        guard let surveyContent else { return false }
        return surveyContent.modules.contains { $0.isRequired == true }
    }

    // MARK: - Experience Event Handling

    /// Reports the survey as seen on the first appearance only.
    func onExperienceSeen() {
        guard let surveyContent, !didSendSeenContentEvent else { return }
        didSendSeenContentEvent = true
        report(SurveyContentEvents.opened(surveyContent, submissionId: submissionId))

        if surveyContent.type == .step {
            onSurveyStepSeen()
        }
    }

    /// Reports completion with the configured thank-you navigation flag.
    func onSurveyCompleted() {
        guard let surveyContent else { return }
        report(SurveyContentEvents.completed(
            surveyContent, submissionId: submissionId, hasDeepLink: surveyContent.thankYouDeepLink != nil
        ))
    }

    /// Closing a thank-you step completes the survey; closing a question dismisses it.
    func onSurveyDismissed() {
        guard
            let surveyContent,
            let surveyStep = getCurrentStepSurveyContent()
        else { return }
        report(SurveyContentEvents.dismissed(surveyContent, submissionId: submissionId, step: surveyStep))
    }

    private func onSurveyStepSeen() {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        report(SurveyContentEvents.stepSeen(surveyContent, submissionId: submissionId, step: surveyStep))
    }

    /// Submits the list's answers before the renderer handles its thank-you or dismissal path.
    func onSurveyListSubmitted(answersPayload: [Payload]) {
        guard let surveyContent else { return }
        report(SurveyContentEvents.listSubmitted(surveyContent, submissionId: submissionId, feedback: answersPayload))
    }

    private func onSurveyModuleSubmitted(_ answersPayload: Payload) {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        report(SurveyContentEvents.stepSubmitted(
            surveyContent, submissionId: submissionId, step: surveyStep, feedback: answersPayload?["value"]
        ))
    }

    private func onSurveyModuleSkipped() {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        report(SurveyContentEvents.stepSkipped(surveyContent, submissionId: submissionId, step: surveyStep))
    }

    /** Logic region, fetch and understand Survey logic, notify screen with next survey step */
    private func isLastStep() -> Bool {
        guard let surveyContent else { return false }
        return currentStep == surveyContent.modules.count - 1
    }

    /// The module at `currentStep`, or nil when the index is outside the survey.
    private func getCurrentStepSurveyContent() -> SurveyStep? {
        surveyContent?.modules[safe: currentStep]
    }

    func moveToNextSurveyStep(
        _ answer: Any?,
        _ answerPayload: Payload
    ) {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        // We are on the last step, close the survey
        if isLastStep(), surveyStep.type == .completed {
            setCompletionDeepLink()
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
            stepLogic: surveyStep.logic ?? [],
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
}
