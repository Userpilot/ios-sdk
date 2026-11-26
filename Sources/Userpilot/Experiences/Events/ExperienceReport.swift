//
//  ExperienceReport.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines what one user moment reports: its host callbacks, then its backend events.
//

/// What one user moment reports: its host callbacks, then its backend events. `FlowContentEvents`,
/// `SurveyContentEvents` and `NPSContentEvents` each return one; a Flow step's `FlowStepOutcome` carries the
/// same two lists.
internal struct ExperienceReport {
    var callbacks: [ExperienceCallback] = []
    var events: [ExperienceEvent] = []
}

/// A host callback fired through the experience delegate, then logged in the experience log format.
internal enum ExperienceCallback: Equatable {
    /// The whole experience's state.
    case experienceState(UserpilotExperienceState)
    /// One step. A Flow numbers it by `position` among `steps_count`; a survey sends neither.
    case stepState(UserpilotExperienceState, stepId: Int, position: Int? = nil, stepsCount: Int? = nil)
}
