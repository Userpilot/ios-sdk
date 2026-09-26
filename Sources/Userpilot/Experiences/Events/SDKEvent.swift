//
//  SDKEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 24/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This file defines the `SDKEvent` protocol and related event names used within the SDK
//  to track and manage different types of user experience events.
//

import Foundation

// MARK: - SDKEvent
/**
 Protocol defining the structure for SDK events.
 */
internal protocol SDKEvent {
    var eventName: String { get }
    var eventPayload: [String: Any] { get }
    var hasDeepLink: Bool { get }
}

extension SDKEvent {

    var hasDeepLink: Bool {
        return false
    }

    func isEventForCloseExperience() -> Bool {
        return self.eventName == SDKEventsName.flowExperienceDismissed.rawValue ||
        self.eventName == SDKEventsName.flowExperienceCompleted.rawValue ||
        self.eventName == SDKEventsName.surveyExperienceDismissed.rawValue ||
        self.eventName == SDKEventsName.surveyExperienceCompleted.rawValue
    }

    func isEventForCloseNPSExperience() -> Bool {
        return self.eventName == SDKEventsName.npsExperienceDismissed.rawValue ||
        self.eventName == SDKEventsName.npsExperienceSubmitted.rawValue
    }

}

/// Used to pass seen content for cached ScreenSessionStateMachine
extension SDKEvent {

    func getContentType() -> ExperienceType {
        if self.eventName == SDKEventsName.flowExperienceDismissed.rawValue ||
            self.eventName == SDKEventsName.flowExperienceCompleted.rawValue ||
            self.eventName == SDKEventsName.flowExperienceSeen.rawValue {
            return .flow
        } else {
            return .survey
        }
    }

    func getContentId() -> Int? {
        if self.eventName == SDKEventsName.flowExperienceDismissed.rawValue ||
            self.eventName == SDKEventsName.flowExperienceCompleted.rawValue ||
            self.eventName == SDKEventsName.flowExperienceSeen.rawValue {
            return self.eventPayload["mobile_content_id"] as? Int
        } else {
            return self.eventPayload["survey_id"] as? Int
        }
    }

    func isSeenContentEvent() -> Bool {
        if self.eventName == SDKEventsName.flowExperienceSeen.rawValue ||
            self.eventName == SDKEventsName.surveyExperienceSeen.rawValue {
            return true
        } else {
            return false
        }
    }

}

/// Used to decide which internal events survive an offline period
extension SDKEvent {

    /// Whether this event is persisted while offline and replayed in the `batch_events` batch.
    ///
    /// Resolves to false for any name the enum does not know, so an event coming from outside
    /// `SDKEventsName` is excluded until someone deliberately opts it in.
    var isOfflineEligible: Bool {
        return SDKEventsName(rawValue: self.eventName)?.isOfflineEligible ?? false
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

    /// Internal events worth persisting while offline. Must stay identical to the Android SDK's set.
    ///
    /// Excluded on purpose:
    /// - `fetchExperienceContent` / `fetchExperienceTheme`: request/response, a stale replay asks the
    ///   backend to re-answer a question with no consumer left.
    /// - `pushNotificationToken`: already self-heals through `resyncPushToken()` on socket open;
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
