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
   - mobileContentId: The Id of the mobile content associated with the event.
   - stepId: The Id of the step associated with the event.
 */
internal class FlowExperienceStepActionEvent: FlowExperienceActionEvent {
    let stepId: Int

    /// Creates a dictionary representation of the event data, including the step ID.
    ///
    /// - Returns: A dictionary containing the action type, mobile content Id, application token, user Id, and step Id.
    override func toMap() -> [String: Any] {
        var map = super.toMap()
        map["step_id"] = stepId
        return map
    }

    init(
        flowId: Int,
        stepId: Int
    ) {
        self.stepId = stepId
        super.init(flowId: flowId)
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
