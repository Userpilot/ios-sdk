//
//  SurveyViewModel.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing the state and interactions of the survey experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler,
//  and storage to handle the experience flow, including data retrieval, theme merging, and
//  sending analytics events through socket requests.
//

import Foundation

internal class SurveyViewModel {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private let experiencesPublisher: ExperiencesPublishing
    private let themeHandler: ThemeHandling
    private let storage: DataStoring

    /// The merged theme data for the survey.
    private(set) var surveyTheme: SurveyTheme?

    /// Mobile content to display.
    private(set) var surveyContent: SurveyContent?

    /// closure to observe the binding state of the content
    var bindData: ((Bool) -> Void)?

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.storage = container.resolve(DataStoring.self)
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
        if let lastModule = surveyContent.modules.last,
            lastModule.type == .completed,
            lastModule.metadata?.enabled == false {
            surveyContent.modules.dropLast()
        }
        self.surveyContent = surveyContent

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
    func onDeepLinkTriggered() {
        guard let surveyContent, let surveyTheme else { return }
        guard let thankYouContent = surveyContent.modules.last, thankYouContent.type == .completed else { return }
        guard let deepLink = thankYouContent.metadata?.iosDeepLink, let url = URL(string: deepLink) else { return }

        experiencesPublisher.triggerDeepLink(url: url)
    }

    // MARK: - Experience Event Handling

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onSurveyOpened() {
        guard let surveyContent else { return }
        let eventExperienceSeen = ExperienceSurveySeenEvent(surveyID: surveyContent.id)
        experiencesPublisher.publishExperienceEvent(eventExperienceSeen)
    }

    /**
     Sends a socket event indicating that a step has been completed.
    */
    func onSurveyCompleted() {
        guard let surveyContent else { return }
        let deeplink: String? = surveyContent.modules.last?.type == .completed ?
            surveyContent.modules.last?.metadata?.androidDeepLink : nil

        let eventExperienceSeen = ExperienceSurveyCompletedEvent(
            surveyID: surveyContent.id,
            hasDeepLinkContent: deeplink != nil
        )
        experiencesPublisher.publishExperienceEvent(eventExperienceSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
    */
    func onSurveyDismissed() {
        guard let surveyContent else { return }
        let eventExperienceDismissed = ExperienceSurveyDismissedEvent(surveyID: surveyContent.id)
        experiencesPublisher.publishExperienceEvent(eventExperienceDismissed)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onSurveySubmitted(answersPayload: [Payload]) {
        guard let surveyContent  else { return }
        let eventContentSubmitted = ExperienceSurveySubmittedEvent(
            surveyID: surveyContent.id,
            feedback: answersPayload)
        experiencesPublisher.publishExperienceEvent(eventContentSubmitted)
    }

}
