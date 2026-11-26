//
//  NPSContentEvents.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps an NPS survey's engagement to its host callbacks and backend events.
//

/// Maps each NPS moment to its one host callback and its one event, in that order.
internal enum NPSContentEvents {

    /// The NPS opened: Started, then NPS seen.
    static func opened() -> ExperienceReport {
        ExperienceReport(callbacks: [.experienceState(.started)], events: [NPSExperienceActionEvent.seen])
    }

    /// The NPS was closed: Dismissed, then NPS dismissed.
    static func dismissed() -> ExperienceReport {
        ExperienceReport(callbacks: [.experienceState(.dismissed)], events: [NPSExperienceActionEvent.dismissed])
    }

    /// The NPS was answered: Submitted, then NPS submitted with the backend `score` and both question keys.
    static func submitted(score: Int, npsKey: String, feedback: Any?, feedbackKey: String) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.experienceState(.submitted)],
            events: [
                NPSExperienceActionEvent.submitted(
                    score: score, npsKey: npsKey, feedback: feedback, feedbackKey: feedbackKey
                )
            ]
        )
    }
}
