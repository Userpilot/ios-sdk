//
//  BaseExperienceViewModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shares instance dependencies and renderer-bound reporting between experience view models.
//

import Foundation

/// Concrete models retain content, theme, answer and engagement policy. UIKit owns their lifetime
/// and reports actual dismissal; constructing a model neither presents UI nor reports it as seen.
internal class BaseExperienceViewModel {
    private(set) weak var userpilot: Userpilot?
    let experiencesPublisher: ExperiencesPublishing
    let logger: Logging
    /// Captured once so delayed callbacks cannot target a replacement presentation.
    let rendererID: UUID?

    init(container: DIContainer) {
        userpilot = container.owner
        experiencesPublisher = container.resolve(ExperiencesPublishing.self)
        rendererID = experiencesPublisher.activeRendererID
        logger = container.resolve(Userpilot.Config.self).logger
    }

    /// The publisher rejects events from a renderer that no longer owns the operation.
    final func publishEvent(_ event: ExperienceEvent) {
        experiencesPublisher.publishInternalSDKEvent(event, rendererID: rendererID)
    }

    /// Records the selected link; final native removal remains the navigation boundary.
    final func setCompletionDeepLink(_ deepLink: String?) {
        experiencesPublisher.setCompletionDeepLink(deepLink, rendererID: rendererID)
    }

    /// Called by the renderer only after UIKit has finished removing its presentation.
    final func onExperienceDismissalCompleted() {
        experiencesPublisher.experienceDidFinishDismissing(rendererID: rendererID)
    }
}
