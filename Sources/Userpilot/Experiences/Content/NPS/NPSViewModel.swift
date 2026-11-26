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

/// Prepares NPS content and reports answers for one renderer using its existing main-thread callbacks.
final class NPSViewModel: BaseExperienceViewModel, ExperienceReporting {

    // MARK: - Properties

    let experienceType = UserpilotExperienceType.nps
    let experienceID: Int? = nil

    let imageLoader: ImageLoading

    /// The theme supplied with the NPS content.
    private(set) var npsTheme: NPSTheme?

    /// Content belonging to this renderer, captured when the view starts.
    private(set) var npsContent: NPSContent?

    /// Reports whether content is available for the renderer to bind.
    var bindData: ((Bool) -> Void)?

    private var didSendSeenContentEvent = false

    // MARK: - Initializers

    /// Initializes the view model with a dependency injection container.
    /// - Parameter container: Dependency injection container providing required services.
    override init(container: DIContainer) {
        self.imageLoader = container.resolve(ImageLoading.self)
        super.init(container: container)
    }

    // MARK: - View Lifecycle

    /// Binds only the content belonging to the controller that launched this renderer.
    func onStart() {
        guard
            let npsContent = experiencesPublisher.getActiveExperience(rendererID: rendererID)?.asNPSContent()
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

    /// Reports NPS as started on the first appearance only.
    func onExperienceSeen() {
        guard npsContent != nil, !didSendSeenContentEvent else { return }
        didSendSeenContentEvent = true
        report(NPSContentEvents.opened())
    }

    /// Reports dismissal; the renderer's completion callback releases presentation ownership.
    func onNPSDismissed() {
        guard npsContent != nil else { return }
        report(NPSContentEvents.dismissed())
    }

    /// Converts the one-based selection to the backend score and preserves both question keys.
    func onNPSSubmitted(_ userAnswer: Int, _ userFollowUpKey: String, _ userFollowUp: String) {
        guard let npsContent else { return }
        report(NPSContentEvents.submitted(
            score: userAnswer - 1,
            npsKey: npsContent.content.survey.key ?? "",
            feedback: userFollowUp,
            feedbackKey: userFollowUpKey
        ))
    }

    /// Opens the configured completion link; dismissal remains owned by the renderer.
    func endNPS(_ completedData: CompletedData?) {
        guard let button = completedData?.button,
              button.buttonAction == .deepLink,
              let deepLink = button.iosDeepLink,
              let url = URL(string: deepLink) else { return }
        setCompletionDeepLink(url.absoluteString)
    }
}
