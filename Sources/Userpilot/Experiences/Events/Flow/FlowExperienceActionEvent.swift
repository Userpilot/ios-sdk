//
//  FlowExperienceActionEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for defining flow experience events.
//

import Foundation

// MARK: - FlowExperienceActionEvent
/**
 Base class representing various types of experience action events for mobile content.

 - Parameters:
   - flowContentId: The Id of the mobile content associated with the event.
   - hasDeepLinkContent: To allow fetch next experience or open deep link screen.
 */
internal class FlowExperienceActionEvent: SDKEvent {
    /// Experience Id
    let flowId: Int
    /// Has deeplink to open it
    let hasDeepLinkContent: Bool

    /// The action type of the event.
    var name: String {
        fatalError("Subclasses need to implement the `name` property.")
    }

    /// Event name, defaulted to "mobile_content".
    var eventName: String {
        return name
    }

    /// Payload for the event represented as a dictionary.
    var eventPayload: [String: Any] {
        return toMap()
    }

    var hasDeepLink: Bool {
        return hasDeepLinkContent
    }

    /// Creates a dictionary representation of the event data.
    ///
    /// - Returns: A dictionary containing the action type, mobile content Id, application token, and user Id.
    func toMap() -> [String: Any] {
        return [
            "mobile_content_id": flowId
        ]
    }

    init(
        flowId: Int,
        hasDeepLinkContent: Bool = false
    ) {
        self.flowId = flowId
        self.hasDeepLinkContent = hasDeepLinkContent
    }
}

// MARK: - FlowExperienceActionEvent Subclasses
/**
 Represents the 'seen' action event.
 */
internal class ExperienceFlowSeenEvent: FlowExperienceActionEvent {
    override var name: String {
        return SDKEventsName.flowExperienceSeen.rawValue
    }
}

/**
 Represents the 'dismissed' action event with extra custom parameters.
*/
internal class ExperienceFlowDismissedEvent: FlowExperienceActionEvent {

    // Custom parameters for the dismissed event
    let stepId: Int

    init(
        flowId: Int,
        stepId: Int
    ) {
        self.stepId = stepId
        super.init(flowId: flowId)
    }

    override var name: String {
        return SDKEventsName.flowExperienceDismissed.rawValue
    }

    /// Combines base event payload with custom parameters.
    override var eventPayload: [String: Any] {
        var basePayload = super.eventPayload
        basePayload["step_id"] = stepId
        return basePayload
    }
}

/**
 Represents the 'completed' action event.
 */
internal class ExperienceFlowCompletedEvent: FlowExperienceActionEvent {
    override var name: String {
        return SDKEventsName.flowExperienceCompleted.rawValue
    }
}
