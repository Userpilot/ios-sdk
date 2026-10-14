//
//  ExperienceEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 14/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines typed engagement metadata consumed by ExperiencesPublisher before transport.
//

/// Renderer engagement has local lifecycle meaning in addition to its backend payload.
internal protocol ExperienceEvent: SDKEvent {
    var name: SDKEventsName { get }
    /// Flow/survey identity for screen history and refreshes. NPS has neither ID here.
    var experience: (type: ExperienceType, id: Int)? { get }
    var hasDeepLink: Bool { get }
}

extension ExperienceEvent {
    var eventName: String { name.rawValue }
    var hasDeepLink: Bool { false }

    /// These events allow a refresh only after the renderer has actually dismissed.
    func isEventForCloseExperience() -> Bool {
        switch name {
        case .flowExperienceDismissed, .flowExperienceCompleted,
             .surveyExperienceDismissed, .surveyExperienceCompleted:
            return true
        default:
            return false
        }
    }

    /// NPS completion closes the operation but does not request another screen event.
    func isEventForCloseNPSExperience() -> Bool {
        return name == .npsExperienceDismissed || name == .npsExperienceSubmitted
    }

    /// Step impressions must not mark a whole experience as seen.
    func isSeenContentEvent() -> Bool {
        return name == .flowExperienceSeen || name == .surveyExperienceSeen
    }
}
