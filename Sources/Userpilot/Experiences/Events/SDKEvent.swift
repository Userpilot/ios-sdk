//
//  File.swift
//  
//
//  Created by Motasem Hamed on 24/11/2024.
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

}

internal enum SDKEventsName: String {
    case fetchExperienceContent = "get_mobile_content"
    case experienceSeen = "seen_mobile_content"
    case experienceDismissed = "dismissed_mobile_content"
    case experienceCompleted = "complete_mobile_content"
    case experienceStepSeen = "seen_mobile_content_step"
    case experienceStepCompleted = "completed_mobile_content_step"
    case fetchExperienceTheme = "fetch_theme"

    case pushNotificationToken = "user_token"
    case pushNotificationOpened = "opened_push_notification"
}
