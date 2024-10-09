//
//  CarouselExperienceViewModel.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing the state and interactions of the carousel experience.
//  It integrates with various dependencies such as the experiences publisher, theme handler,
//  and storage to handle the experience flow, including data retrieval, theme merging, and
//  sending analytics events through socket requests.
//

import Foundation

internal class CarouselExperienceViewModel {

    // MARK: - Properties

    private let experiencesPublisher: ExperiencesPublishing
    private let themeHandler: ThemeHandling
    private let config: UserPilot.Config
    private let storage: DataStoring
    let imageLoader: ImageLoading

    private(set) var mergedTheme = [ThemeData]()
    private(set) var carouselContent: CarouselContent?

    var bindData: (() -> Void)?
    private var lastStep = 0

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.config = container.resolve(UserPilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.imageLoader = container.resolve(ImageLoading.self)
    }

    // MARK: - View Lifecycle

    /**
     Starts the view model by retrieving and setting up the carousel content.
     Initializes the theme for each step and binds data for UI updates.
     */
    func onStart() {
        guard
            let carouselContent = experiencesPublisher.getActiveCarousel()
        else { return }

        self.carouselContent = carouselContent
        let baseTheme = themeHandler.getThemeById(carouselContent.baseThemeID)

        carouselContent.steps.forEach { step in
            mergedTheme.append(
                themeHandler.mergeThemes(
                    baseTheme,
                    carouselContent.mobileTheme.themeData,
                    step.mobileTheme?.themeData
                )
            )
        }

        bindData?()
    }

    /// Returns the total number of steps in the carousel.
    var carouselStepsCount: Int {
        return carouselContent?.steps.count ?? 0
    }

    // MARK: - Experience Event Handling

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onExperienceOpened() {
        let eventStepCompleted = ExperienceStepSeenEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID,
            stepID: "")
        experiencesPublisher.sendSocketRequest(eventStepCompleted)

        let eventStepSeen = ExperienceSeenEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID)
        experiencesPublisher.sendSocketRequest(eventStepSeen)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onExperienceCompleted() {
        let eventStepCompleted = ExperienceStepCompletedEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID,
            stepID: "")
        experiencesPublisher.sendSocketRequest(eventStepCompleted)

        let eventStepSeen = ExperienceCompletedEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID)
        experiencesPublisher.sendSocketRequest(eventStepSeen)
    }

    /**
     Handles the change of steps in the carousel.
     
     - Parameter step: The current step number.
     */
    func onStepChanged(step: Int) {
        guard step > lastStep else { return }
        lastStep = step

        let eventStepCompleted = ExperienceStepCompletedEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID,
            stepID: "")
        experiencesPublisher.sendSocketRequest(eventStepCompleted)

        let eventStepSeen = ExperienceStepSeenEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID,
            stepID: "")
        experiencesPublisher.sendSocketRequest(eventStepSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
     
     - Parameter step: The step number that was dismissed.
     */
    func onDismissStep(step: Int) {
        let eventStepDismissed = ExperienceStepDismissedEvent(
            mobileContentID: 4,
            appToken: config.token,
            userID: storage.userID,
            stepID: "")
        experiencesPublisher.sendSocketRequest(eventStepDismissed)

        let eventCarouselDismissed = ExperienceDismissedEvent(
            mobileContentID: 0,
            appToken: config.token,
            userID: storage.userID)
        experiencesPublisher.sendSocketRequest(eventCarouselDismissed)
    }

    // MARK: - Deep Link Handling

    /**
     Handles navigation to a deep link specified in the last step of the carousel.
     If a deep link exists, the navigation delegate triggers the navigation action.
     */
    func onDeepLinkTriggered() {
        guard
            let deepLink = carouselContent?.steps.last?.buttonAction?.deepLink,
            let url = URL(string: deepLink)
        else { return }
        config.navigationDelegate?.navigate(to: url, completion: {_ in })
    }
}
