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
    private let experiencesPublisher: ExperiencesPublishing
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
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.imageLoader = container.resolve(ImageLoading.self)
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
        onNPSOpened()
    }

    /// Return wither the content is RTL
    var isRTL: Bool {
        return (npsContent?.localeCode ?? "en").isRTL == true
    }
    // MARK: - Experience Event Handling

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onNPSOpened() {
        guard npsContent != nil else { return }
        let eventExperienceSeen = ExperienceNPSSeenEvent()
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
    */
    func onNPSDismissed() {
        guard npsContent != nil else { return }
        let eventExperienceDismissed = ExperienceNPSDismissedEvent()
        experiencesPublisher.publishInternalSDKEvent(eventExperienceDismissed)
    }

    func onNPSSubmitted(_ userAnswer: Int, _ userFollowUpKey: String, _ userFollowUp: String) {
        guard let npsContent else { return }
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

}
