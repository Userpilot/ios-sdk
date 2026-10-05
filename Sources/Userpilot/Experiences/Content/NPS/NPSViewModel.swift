//
//  NPSViewModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Prepares NPS content and reports survey actions through the experiences publisher.
//  UIKit owns presentation and reports actual dismissal completion through this view model.
//

import Foundation

/// Renderer-facing NPS state and actions. UIKit owns presentation and dismissal completion.
protocol NPSViewModeling: AnyObject {
    var npsTheme: NPSTheme? { get }
    var npsContent: NPSContent? { get }
    var imageLoader: ImageLoading { get }
    var isRTL: Bool { get }
    var bindData: ((Bool) -> Void)? { get set }

    func onStart()
    func onExperienceSeen()
    func onExperienceDismissalCompleted()
    func onNPSDismissed()
    func onNPSSubmitted(_ userAnswer: Int, _ userFollowUpKey: String, _ userFollowUp: String)
    func endNPS(_ completedData: CompletedData?)
}

/// Prepares NPS content and reports answers for one renderer using its existing main-thread callbacks.
final class NPSViewModel: NPSViewModeling {

    // MARK: - Properties

    /// Weak reference to the owning `Userpilot` instance.
    private weak var userpilot: Userpilot?
    private let experiencesPublisher: ExperiencesPublishing
    private let rendererID: UUID?
    private let logger: Logging
    let imageLoader: ImageLoading

    /// The theme supplied with the NPS content.
    private(set) var npsTheme: NPSTheme?

    /// Content belonging to this renderer, captured when the view starts.
    private(set) var npsContent: NPSContent?

    /// Reports whether content is available for the renderer to bind.
    var bindData: ((Bool) -> Void)?

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        self.rendererID = experiencesPublisher.activeRendererID
        self.imageLoader = container.resolve(ImageLoading.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
    }

    // MARK: - View Lifecycle

    /// Binds only the content belonging to the controller that launched this renderer.
    func onStart() {
        guard
            let npsContent = experiencesPublisher.getActiveMobileContent(rendererID: rendererID)?.asNPSContent()
        else {
            bindData?(false)
            return
        }
        self.npsContent = npsContent

        npsTheme = npsContent.npsTheme
        bindData?(true)
    }

    /// Uses the existing English fallback before content is available.
    var isRTL: Bool {
        return (npsContent?.localeCode ?? "en").isRTL == true
    }
    // MARK: - Experience Event Handling

    /// Retains the presentation delay before reporting NPS as started.
    func onExperienceSeen() {
        delay(0.3) { [weak self] in
            self?.onNPSOpened()
        }
    }

    /// Reports the start after content binding and the renderer's seen callback.
    private func onNPSOpened() {
        guard npsContent != nil else { return }
        notifyExperienceState(.started)

        let eventExperienceSeen = ExperienceNPSSeenEvent()
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSeen, rendererID: rendererID)
    }

    /// Reports dismissal; the renderer's completion callback releases presentation ownership.
    func onNPSDismissed() {
        guard npsContent != nil else { return }
        notifyExperienceState(.dismissed)

        let eventExperienceDismissed = ExperienceNPSDismissedEvent()
        experiencesPublisher.publishInternalSDKEvent(eventExperienceDismissed, rendererID: rendererID)
    }

    /// Converts the one-based selection to the backend score and preserves both question keys.
    func onNPSSubmitted(_ userAnswer: Int, _ userFollowUpKey: String, _ userFollowUp: String) {
        guard let npsContent else { return }
        notifyExperienceState(.submitted)

        let eventExperienceSubmitted = ExperienceNPSSubmittedEvent(
            score: userAnswer - 1,
            npsKey: npsContent.content.survey.key ?? "",
            feedback: userFollowUp,
            feedbackKey: userFollowUpKey
        )
        experiencesPublisher.publishInternalSDKEvent(eventExperienceSubmitted, rendererID: rendererID)
    }

    /// Opens the configured completion link; dismissal remains owned by the renderer.
    func endNPS(_ completedData: CompletedData?) {
        if completedData?.button.buttonAction == .deepLink,
           let deepLink = completedData?.button.iosDeepLink,
           let url = URL(string: deepLink) {
            experiencesPublisher.triggerDeepLink(url: url)
        }
    }

    /// Notify the publisher after the NPS view has finished dismissing.
    func onExperienceDismissalCompleted() {
        experiencesPublisher.experienceDidFinishDismissing(rendererID: rendererID)
    }

    // MARK: - Reporting

    /// Keep the delegate, log and subsequent event publication in their established order.
    private func notifyExperienceState(_ state: UserpilotExperienceState) {
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: .nps,
            experienceId: nil,
            experienceState: state
        )
        logExperience(state: state.rawValueString)
    }

    private func logExperience(state: String) {
        logger.info(
            "🌠 Userpilot experience -> type: %{public}@, state: %{public}@",
            UserpilotExperienceType.nps.rawValueString,
            state
        )
    }
}
