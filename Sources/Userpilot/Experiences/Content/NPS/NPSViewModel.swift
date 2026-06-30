//
//  NPSViewModel.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing the state and interactions of the survey experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler,
//  including data retrieval, theme merging, and sending analytics events through socket requests.
//

import Foundation

internal class NPSViewModel {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?
    private let experiencesPublisher: ExperiencesPublishing
    private let logger: Logging
    let imageLoader: ImageLoading

    /// The merged theme data for the survey.
    private(set) var npsTheme: NPSTheme?

    /// Survey content to display.
    private(set) var npsContent: NPSContent?

    /// closure to observe the binding state of the content
    var bindData: ((Bool) -> Void)?

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.imageLoader = container.resolve(ImageLoading.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the survey content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            let npsContent = experiencesPublisher.getActiveMobileContent()?.asNPSContent()
        else {
            bindData?(false)
            return
        }
        self.npsContent = npsContent

        // Setup theme
        npsTheme = npsContent.npsTheme

        // Bind data
        bindData?(true)
    }

    /// Return wither the content is RTL
    var isRTL: Bool {
        return (npsContent?.localeCode ?? "en").isRTL == true
    }
    // MARK: - Experience Event Handling

    func onExperienceSeen() {
        delay(0.3) { [weak self] in
            self?.onNPSOpened()
        }
    }

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onNPSOpened() {
        guard npsContent != nil else { return }
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .nps,
            experienceId: nil,
            experienceState: .started
        )
        logExperience(state: UserpilotExperienceState.started.rawValueString)

        let eventExperienceSeen = ExperienceNPSSeenEvent()
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
    */
    func onNPSDismissed() {
        guard npsContent != nil else { return }
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .nps,
            experienceId: nil,
            experienceState: .dismissed
        )
        logExperience(state: UserpilotExperienceState.dismissed.rawValueString)

        let eventExperienceDismissed = ExperienceNPSDismissedEvent()
        experiencesPublisher.publishInternalSDKEvent(eventExperienceDismissed)
    }

    func onNPSSubmitted(_ userAnswer: Int, _ userFollowUpKey: String, _ userFollowUp: String) {
        guard let npsContent else { return }
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .nps,
            experienceId: nil,
            experienceState: .submitted
        )
        logExperience(state: UserpilotExperienceState.submitted.rawValueString)

        let eventExperienceSubmitted = ExperienceNPSSubmittedEvent(
            score: userAnswer - 1,
            npsKey: npsContent.content.survey.key ?? "",
            feedback: userFollowUp,
            feedbackKey: userFollowUpKey
        )
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSubmitted)
    }

    func endNPS(_ completedData: CompletedData?) {
        if completedData?.button.buttonAction == .deepLink,
           let deepLink = completedData?.button.iosDeepLink,
           let url = URL(string: deepLink) {
            experiencesPublisher.triggerDeepLink(url: url)
        }
    }

    /// Notify the publisher after the NPS view has finished dismissing.
    func onExperienceDismissalCompleted() {
        experiencesPublisher.experienceDidFinishDismissing()
    }

    // MARK: - Logging

    private func logExperience(state: String) {
        logger.info(
            "🌠 Userpilot experience -> type: %{public}@, state: %{public}@",
            UserpilotExperienceType.nps.rawValueString,
            state
        )
    }
}
