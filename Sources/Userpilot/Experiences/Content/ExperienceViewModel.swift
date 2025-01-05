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

internal class ExperienceViewModel {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?
    private let experiencesPublisher: ExperiencesPublishing
    private let themeHandler: ThemeHandling
    private let storage: DataStoring
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

    /// Mobile content to display.
    private(set) var mobileContent: MobileContent?
    var slideOutContent: Step? {
        mobileContent?.steps.first
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
        self.themeHandler = container.resolve(ThemeHandling.self)
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
            let mobileContent = experiencesPublisher.getActiveMobileContent()
        else {
            bindData?(false)
            return
        }
        self.mobileContent = mobileContent
        let baseTheme = themeHandler.getThemeById(mobileContent.baseThemeID)

        mobileContent.steps.forEach { step in
            mergedTheme.append(
                themeHandler.mergeThemes(
                    baseTheme,
                    mobileContent.mobileTheme.themeData,
                    step.mobileTheme
                )
            )
        }

        var shouldBindCarousel = true
        // Handle safe area region in case there is an issue with the data
        if mobileContent.steps.isEmpty ||
            (mobileContent.type == .carousel && carouselTheme.isEmpty) ||
            (mobileContent.type == .slideout &&
             (mergedTheme.isEmpty || mergedTheme.first?.slideOut == nil)) {
            shouldBindCarousel = false
        }

        bindData?(shouldBindCarousel)
        if shouldBindCarousel {
            onExperienceOpened()
        }
    }

    var isRTL: Bool {
        return (mobileContent?.localeCode ?? "en").isRTL == true
    }

    /// Returns the total number of steps in the carousel.
    var carouselStepsCount: Int {
        return mobileContent?.steps.count ?? 0
    }

    // MARK: - Experience Event Handling

    /**
     Sends a socket event indicating that an experience has been opened.
     */
    private func onExperienceOpened() {
        guard
            let mobileContent = mobileContent,
            let step = mobileContent.steps.first
        else { return }

        userpilot?.experienceDelegate?.onExperienceStateChanged(
            id: mobileContent.id,
            state: .started
        )

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            id: step.id,
            state: .started,
            experienceId: mobileContent.id,
            step: 1,
            totalSteps: mobileContent.steps.count
        )

        let eventExperienceSeen = ExperienceSeenEvent(mobileContentID: mobileContent.id)
        experiencesPublisher.publishExperienceEvent(eventExperienceSeen)

        let eventStepSeen = ExperienceStepSeenEvent(
            mobileContentID: mobileContent.id,
            stepID: step.id)
        experiencesPublisher.publishExperienceEvent(eventStepSeen)
    }

    /**
     Sends a socket event indicating that the experience has been completed.
     */
    func onExperienceCompleted() {
        guard
            let mobileContent = mobileContent,
            let step = mobileContent.steps.last
        else { return }

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            id: step.id,
            state: .completed,
            experienceId: mobileContent.id,
            step: mobileContent.steps.count,
            totalSteps: mobileContent.steps.count
        )

        userpilot?.experienceDelegate?.onExperienceStateChanged(
            id: mobileContent.id,
            state: .completed
        )

        let hasDeepLink = !(step.buttonAction?.deepLink?.isEmpty ?? true)

        let eventStepCompleted = ExperienceStepCompletedEvent(
            mobileContentID: mobileContent.id,
            stepID: step.id)
        experiencesPublisher.publishExperienceEvent(eventStepCompleted)

        let eventContentCompleted = ExperienceCompletedEvent(
            mobileContentID: mobileContent.id,
            hasDeepLinkContent: hasDeepLink)
        experiencesPublisher.publishExperienceEvent(eventContentCompleted)
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
            let mobileContent,
            let currentStep = mobileContent.steps[safe: step],
            let oldStep = mobileContent.steps[safe: step - 1]
        else { return }

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            id: currentStep.id,
            state: .completed,
            experienceId: mobileContent.id,
            step: step - 1,
            totalSteps: mobileContent.steps.count
        )

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            id: currentStep.id,
            state: .started,
            experienceId: mobileContent.id,
            step: step,
            totalSteps: mobileContent.steps.count
        )

        let eventStepCompleted = ExperienceStepCompletedEvent(
            mobileContentID: mobileContent.id,
            stepID: oldStep.id)
        experiencesPublisher.publishExperienceEvent(eventStepCompleted)

        let eventStepSeen = ExperienceStepSeenEvent(
            mobileContentID: mobileContent.id,
            stepID: currentStep.id)
        experiencesPublisher.publishExperienceEvent(eventStepSeen)
    }

    /**
     Sends a socket event indicating that a step has been dismissed.
     
     - Parameter step: The step number that was dismissed.
     */
    func onDismissStep() {
        guard
            let mobileContent,
            let step = mobileContent.steps[safe: lastStep]
        else { return }

        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            id: step.id,
            state: .dismissed,
            experienceId: mobileContent.id,
            step: lastStep,
            totalSteps: mobileContent.steps.count
        )

        userpilot?.experienceDelegate?.onExperienceStateChanged(
            id: mobileContent.id,
            state: .dismissed
        )

        let eventExperienceDismissed = ExperienceDismissedEvent(
            mobileContentID: mobileContent.id,
            stepId: step.id)
        experiencesPublisher.publishExperienceEvent(eventExperienceDismissed)
    }

    // MARK: - Deep Link Handling

    /**
     Handles navigation to a deep link specified in the last step of the carousel.
     If a deep link exists, the navigation delegate triggers the navigation action.
     */
    func onDeepLinkTriggered() {
        guard
            let deepLink = mobileContent?.steps.last?.buttonAction?.deepLink,
            let url = URL(string: deepLink)
        else { return }
        experiencesPublisher.triggerDeepLink(url: url)
    }
}
