//
//  FlowExperienceStepActionEvent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for defining flow experience `step` events.
//

import Foundation

// MARK: - FlowExperienceStepActionEvent
/**
 Base class representing various types of experience step action events for mobile content.

 - Parameters:
   - mobileContentId: The ID of the mobile content associated with the event.
   - stepID: The ID of the step associated with the event.
 */
internal class FlowExperienceStepActionEvent: FlowExperienceActionEvent {
    let stepID: Int

    /// Creates a dictionary representation of the event data, including the step ID.
    ///
    /// - Returns: A dictionary containing the action type, mobile content ID, application token, user ID, and step ID.
    override func toMap() -> [String: Any] {
        var map = super.toMap()
        map["step_id"] = stepID
        return map
    }

    init(flowID: Int, stepID: Int) {
        self.stepID = stepID
        super.init(flowID: flowID)
    }
}

// MARK: - FlowExperienceStepActionEvent Subclasses
/**
 Represents the 'seen' step action event.
 */
internal class ExperienceFlowStepSeenEvent: FlowExperienceStepActionEvent {
    override var name: String {
        return SDKEventsName.flowExperienceStepSeen.rawValue
    }
}

/**
 Represents the 'completed' step action event.
 */
internal class ExperienceFlowStepCompletedEvent: FlowExperienceStepActionEvent {
    override var name: String {
        return SDKEventsName.flowExperienceStepCompleted.rawValue
    }
}
