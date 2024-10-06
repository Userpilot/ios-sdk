//
//  File.swift
//  
//
//  Created by Motasem Hamed on 30/09/2024.
//

import Foundation

internal class CarouselExperienceViewModel {

    private let experiencesPublisher: ExperiencesPublishing
    private let themeHandler: ThemeHandling
    private let config: UserPilot.Config
    private let storage: DataStoring

    init(container: DIContainer) {
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.config = container.resolve(UserPilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
    }

    private(set) var mergedTheme = [ThemeData]()
    private(set) var carouselContent: CarouselData?

    var bindData: (() -> Void)?
    var dismissViewController: (() -> Void)?
    private var lastStep = 0

    func onStart() {
        guard let carouselContent = experiencesPublisher.getActiveCarousel(),
              let themeId = carouselContent.mobileTheme?.id
        else { return }
        self.carouselContent = carouselContent
        let baseTheme = themeHandler.getThemeById(themeId)

        carouselContent.steps.forEach { step in
            mergedTheme.append(
                themeHandler.mergeThemes(
                    baseTheme,
                    carouselContent.mobileTheme?.themeData,
                    step.mobileTheme?.themeData)
            )
        }

        bindData?()
    }

    var carouselStepsCount: Int {
        return carouselContent?.steps.count ?? 0
    }

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onExperienceOpened() {
        let eventStepCompleted = ExperienceStepSeenEvent(
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID,
            stepId: "")
        experiencesPublisher.sendSocketRequest(eventStepCompleted)

        let eventStepSeen = ExperienceSeenEvent(
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID)
        experiencesPublisher.sendSocketRequest(eventStepSeen)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onExperienceCompleted() {
        let eventStepCompleted = ExperienceStepCompletedEvent(
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID,
            stepId: "")
        experiencesPublisher.sendSocketRequest(eventStepCompleted)

        let eventStepSeen = ExperienceCompletedEvent(
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID)
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
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID,
            stepId: "")
        experiencesPublisher.sendSocketRequest(eventStepCompleted)

        let eventStepSeen = ExperienceStepSeenEvent(
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID,
            stepId: "")
        experiencesPublisher.sendSocketRequest(eventStepSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.

     - Parameter step: The step number that was dismissed.
     */
    func onDismissStep(step: Int) {
        let eventStepDismissed = ExperienceStepDismissedEvent(
            mobileContentId: 4,
            appToken: config.token,
            userId: storage.userID,
            stepId: "")
        experiencesPublisher.sendSocketRequest(eventStepDismissed)

        let eventCarouselDismissed = ExperienceDismissedEvent(
            mobileContentId: 0,
            appToken: config.token,
            userId: storage.userID)
        experiencesPublisher.sendSocketRequest(eventCarouselDismissed)
    }

    func onDeepLinkTriggered() {
        guard
            let deepLink = carouselContent?.steps.last?.buttonAction?.deepLink,
            let url = URL(string: deepLink)
        else { return }
        config.navigationDelegate?.navigate(to: url, completion: { [weak self] _ in
            // self?.dismissViewController?()
        })
    }

}
