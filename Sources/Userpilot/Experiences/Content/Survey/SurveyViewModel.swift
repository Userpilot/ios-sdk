//
//  SurveyViewModel.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing the state and interactions of the survey experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler, to
//  handle the experience flow, including data retrieval, theme merging, and
//  sending analytics events through socket requests.
//

import Foundation

internal class SurveyViewModel {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private let experiencesPublisher: ExperiencesPublishing
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

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the survey content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            var surveyContent = experiencesPublisher.getActiveMobileContent()?.asSurveyContent()
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
        let baseTheme = themeHandler.getThemeById(surveyContent.baseThemeID)
        surveyTheme = themeHandler.mergeSurveyThemes(
            baseTheme, surveyContent.surveyTheme.themeData
        )

        // Handle safe area region in case there is an issue with the data
        var shouldBindSurvey = true
        if surveyContent == nil || surveyContent.modules.isEmpty || surveyTheme == nil {
            shouldBindSurvey = false
        }

        // Bind data
        bindData?(shouldBindSurvey)
        if shouldBindSurvey {
            onSurveyOpened()
        }
    }

    /// Return wither the content is RTL
    var isRTL: Bool {
        return (surveyContent?.localeCode ?? "en").isRTL == true
    }

    /// Trigger thank you module
    func showThankYouMessage() {
        guard let surveyContent, let surveyTheme else { return }
        if surveyContent.modules.last?.type == .completed {
            experiencesPublisher.showThankYouMessage(surveyContent, surveyTheme)
        } else {
            onSurveyCompleted()
        }
    }

    /// Triggered the deep link from thank you message.
    private func onDeepLinkTriggered() {
        guard
            let surveyContent,
            let surveyTheme,
            let thankYouContent = surveyContent.modules.last,
            thankYouContent.type == .completed,
            thankYouContent.metadata?.buttonAction == .deepLink,
            let deepLink = thankYouContent.metadata?.iosDeepLink,
            let url = URL(string: deepLink)
        else { return }
        experiencesPublisher.triggerDeepLink(url: url)
    }

    func isAnyQuestionRequired() -> Bool {
        guard let surveyContent else { return false }
        return surveyContent.modules.contains { $0.isRequired == true }
    }

    // MARK: - Experience Event Handling

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onSurveyOpened() {
        guard let surveyContent else { return }
        let eventExperienceSeen = ExperienceSurveySeenEvent(surveyID: surveyContent.id)
        experiencesPublisher.publishSDKEvent(eventExperienceSeen)

        if surveyContent.type == .step {
            onSurveyStepSeen()
        }
    }

    /**
     Sends a socket event indicating that a step has been completed.
    */
    func onSurveyCompleted() {
        guard let surveyContent else { return }
        let deeplink: String? = (
            surveyContent.modules.last?.type == .completed
            && surveyContent.modules.last?.metadata?.buttonAction == .deepLink
        ) ? surveyContent.modules.last?.metadata?.iosDeepLink : nil

        let eventExperienceSeen = ExperienceSurveyCompletedEvent(
            surveyID: surveyContent.id,
            hasDeepLinkContent: deeplink != nil
        )
        experiencesPublisher.publishSDKEvent(eventExperienceSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
    */
    func onSurveyDismissed() {
        guard
            let surveyContent,
            let surveyStep = getCurrentStepSurveyContent()
        else { return }
        if surveyStep.type == .completed {
            let eventExperienceSeen = ExperienceSurveyCompletedEvent(
                surveyID: surveyContent.id,
                hasDeepLinkContent: false
            )
            experiencesPublisher.publishSDKEvent(eventExperienceSeen)
        } else {
            let eventExperienceDismissed = ExperienceSurveyDismissedEvent(
                surveyID: surveyContent.id,
                moduleID: surveyContent.type == .list ? nil : surveyStep.id,
                type: surveyContent.type == .list ? nil : surveyStep.type.rawValue)
            experiencesPublisher.publishSDKEvent(eventExperienceDismissed)
        }
    }

    private func onSurveyStepSeen() {
        guard let surveyStep = getCurrentStepSurveyContent() else { return }
        let eventStepSeen = ExperienceSurveyStepSeenEvent(
            surveyID: surveyStep.id,
            moduleID: surveyStep.id,
            type: surveyStep.type.rawValue
        )
        experiencesPublisher.publishSDKEvent(eventStepSeen)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onSurveyListSubmitted(answersPayload: [Payload]) {
        guard let surveyContent  else { return }
        let eventContentSubmitted = ExperienceSurveySubmittedEvent(
            surveyID: surveyContent.id,
            feedback: answersPayload
        )
        experiencesPublisher.publishSDKEvent(eventContentSubmitted)
    }

    private func onSurveyModuleSubmitted(_ answersPayload: Payload) {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }

        guard let surveyStep = getCurrentStepSurveyContent() else { return }
        let eventStepSubmitted = ExperienceSurveyStepSubmittedEvent(
            surveyID: surveyContent.id,
            moduleID: surveyStep.id,
            type: surveyStep.type.rawValue,
            feedback: answersPayload?["value"]
        )
        experiencesPublisher.publishSDKEvent(eventStepSubmitted)
    }

    private func onSurveyModuleSkipped() {
        guard let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        let eventStepSkipped = ExperienceSurveyStepSkippedEvent(
            surveyID: surveyContent.id,
            moduleID: surveyStep.id,
            type: surveyStep.type.rawValue
        )
        experiencesPublisher.publishSDKEvent(eventStepSkipped)
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

    func moveToNextSurveyStep(_ answer: Any?, _ answerPayload: Payload) {
        guard  let surveyContent, let surveyStep = getCurrentStepSurveyContent() else { return }
        // We are on the last step, close the survey
        if isLastStep(), surveyStep.type == .completed {
            onDeepLinkTriggered()
            onSurveyCompleted()
            closeSurvey?()
            return
        }

        // Submit the answer payload in all cases while we are not on the thank you view
        if let answer = answer {
            onSurveyModuleSubmitted(answerPayload)
        } else {
            onSurveyModuleSkipped()
        }

        // If we are on the last question, close the survey after submitting the answer
        if isLastStep() {
            onSurveyCompleted()
            closeSurvey?()
            return
        }

        // Get the next step index based on the logic handler
        let (nextStep, endSurvey) = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: surveyContent.modules[currentStep].logic ?? [],
            answer: answer,
            surveySteps: surveyContent.modules
        )

        if endSurvey {
            onSurveyCompleted()
            closeSurvey?()
            return
        }

        // Determine whether to move to the next question or to a specified step
        currentStep = (nextStep == -1) ? (currentStep + 1) : nextStep

        // Update seen state for the next module
        if getCurrentStepSurveyContent()?.type != .completed {
            onSurveyStepSeen()
        }

        // Update LiveData to notify that the next question is ready
        bindNextSurveyStep?()
    }

}
