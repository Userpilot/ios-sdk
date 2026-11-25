//
//  SurveyContentEvents.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps a survey's engagement to its host callbacks and backend events.
//

/// Maps each survey moment to its host callbacks and the events it sends, in order. Every event carries the
/// renderer's `submissionId`; step callbacks carry no position or step count.
internal enum SurveyContentEvents {

    /// The survey opened: Started, then survey seen.
    static func opened(_ survey: SurveyContent, submissionId: Int64) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.experienceState(.started)],
            events: [SurveyExperienceActionEvent.seen(surveyId: survey.id, submissionId: submissionId)]
        )
    }

    /// `step` was shown: step Started, then step seen.
    static func stepSeen(_ survey: SurveyContent, submissionId: Int64, step: SurveyStep) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.stepState(.started, stepId: step.id)],
            events: [
                SurveyExperienceStepActionEvent.seen(
                    surveyId: survey.id, submissionId: submissionId, moduleId: step.id, type: step.type.rawValue
                )
            ]
        )
    }

    /// `step` was answered: step Submitted, then step submitted with `feedback`.
    static func stepSubmitted(
        _ survey: SurveyContent,
        submissionId: Int64,
        step: SurveyStep,
        feedback: Any?
    ) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.stepState(.submitted, stepId: step.id)],
            events: [
                SurveyExperienceStepActionEvent.submitted(
                    surveyId: survey.id,
                    submissionId: submissionId,
                    moduleId: step.id,
                    type: step.type.rawValue,
                    feedback: feedback
                )
            ]
        )
    }

    /// `step` was left unanswered: step Skipped, then step skipped.
    static func stepSkipped(_ survey: SurveyContent, submissionId: Int64, step: SurveyStep) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.stepState(.skipped, stepId: step.id)],
            events: [
                SurveyExperienceStepActionEvent.skipped(
                    surveyId: survey.id, submissionId: submissionId, moduleId: step.id, type: step.type.rawValue
                )
            ]
        )
    }

    /// A list survey's answers were sent together: Submitted, then survey submitted with `feedback`.
    static func listSubmitted(_ survey: SurveyContent, submissionId: Int64, feedback: [Payload]) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.experienceState(.submitted)],
            events: [
                SurveyExperienceActionEvent.submitted(
                    surveyId: survey.id, submissionId: submissionId, feedback: feedback
                )
            ]
        )
    }

    /// The survey completed: Completed, then survey completed with `hasDeepLink`.
    static func completed(_ survey: SurveyContent, submissionId: Int64, hasDeepLink: Bool) -> ExperienceReport {
        ExperienceReport(
            callbacks: [.experienceState(.completed)],
            events: [
                SurveyExperienceActionEvent.completed(
                    surveyId: survey.id, submissionId: submissionId, hasDeepLink: hasDeepLink
                )
            ]
        )
    }

    /// Closing the thank-you `step` completes the survey without a link; closing a question dismisses it.
    /// A list survey's dismissal names no module.
    static func dismissed(_ survey: SurveyContent, submissionId: Int64, step: SurveyStep) -> ExperienceReport {
        if step.type == .completed {
            return completed(survey, submissionId: submissionId, hasDeepLink: false)
        }
        let isList = survey.type == .list
        return ExperienceReport(
            callbacks: [.experienceState(.dismissed)],
            events: [
                SurveyExperienceActionEvent.dismissed(
                    surveyId: survey.id,
                    submissionId: submissionId,
                    moduleId: isList ? nil : step.id,
                    type: isList ? nil : step.type.rawValue
                )
            ]
        )
    }
}
