//
//  SDKEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Defines the shared transport contract and offline policy for internal SDK events.
//

import Foundation

/// Transport values consumed by analytics, socket delivery and offline storage.
internal protocol SDKEvent {
    var eventName: String { get }
    var eventPayload: [String: Any] { get }
}

extension SDKEvent {
    /// Unknown names are excluded until explicitly admitted by the offline policy.
    var isOfflineEligible: Bool {
        return SDKEventsName(rawValue: eventName)?.isOfflineEligible ?? false
    }
}

internal enum SDKEventsName: String, CaseIterable {
    case fetchExperienceContent = "get_mobile_content"
    case fetchExperienceTheme = "fetch_theme"

    case flowExperienceSeen = "seen_mobile_content"
    case flowExperienceDismissed = "dismissed_mobile_content"
    case flowExperienceCompleted = "complete_mobile_content"
    case flowExperienceStepSeen = "seen_mobile_content_step"
    case flowExperienceStepCompleted = "completed_mobile_content_step"

    case surveyExperienceSeen = "seen_survey"
    case surveyExperienceDismissed = "dismissed_survey"
    case surveyExperienceCompleted = "completed_survey"
    case surveyExperienceSubmitted = "completed_survey_module_batch"
    case surveyExperienceStepSeen = "seen_survey_module"
    case surveyExperienceStepSkipped = "skipped_survey_module"
    case surveyExperienceStepSubmitted = "completed_survey_module"

    case npsExperienceSeen = "seen_NPS"
    case npsExperienceDismissed = "dismiss_NPS"
    case npsExperienceSubmitted = "NPS_feedback"

    case pushNotificationToken = "user_token"
    case pushNotificationOpened = "opened_push_notification"
    case userLogout = "user_logout"
}

extension SDKEventsName {

    /// Internal events eligible for persistence and replay in offline batches.
    ///
    /// Excluded on purpose:
    /// - `fetchExperienceContent` / `fetchExperienceTheme`: request/response, a stale replay asks the
    ///   backend to re-answer a question with no consumer left.
    /// - `pushNotificationToken`: the push monitor retries the current cached token on socket open;
    ///   replaying would send a stale token instead of the current one.
    /// - `userLogout`: logout also clears the offline store it would be written into.
    ///
    /// Every case is listed explicitly with no `default:`, so a newly added event fails to compile
    /// until someone decides which side it belongs on.
    var isOfflineEligible: Bool {
        switch self {
        case .flowExperienceSeen,
             .flowExperienceDismissed,
             .flowExperienceCompleted,
             .flowExperienceStepSeen,
             .flowExperienceStepCompleted,
             .surveyExperienceSeen,
             .surveyExperienceDismissed,
             .surveyExperienceCompleted,
             .surveyExperienceSubmitted,
             .surveyExperienceStepSeen,
             .surveyExperienceStepSkipped,
             .surveyExperienceStepSubmitted,
             .npsExperienceSeen,
             .npsExperienceDismissed,
             .npsExperienceSubmitted,
             .pushNotificationOpened:
            return true
        case .fetchExperienceContent,
             .fetchExperienceTheme,
             .pushNotificationToken,
             .userLogout:
            return false
        }
    }

}
