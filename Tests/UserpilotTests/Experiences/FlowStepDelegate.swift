//
//  FlowStepDelegate.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Records the experience and step states a renderer reports to the host delegate.
//

import Foundation
@testable import Userpilot

final class FlowStepDelegate: UserpilotExperienceDelegate {
    /// Experience callbacks, one entry in `flowStates` and `flowIDs` per call.
    var flowStates: [UserpilotExperienceState] = []
    var flowIDs: [Int?] = []
    /// Step callbacks, one entry in `states`, `stepIDs`, `positions` and `totals` per call.
    var states: [UserpilotExperienceState] = []
    var stepIDs: [Int] = []
    var positions: [Int?] = []
    var totals: [Int?] = []

    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?,
        experienceState: UserpilotExperienceState
    ) {
        flowStates.append(experienceState)
        flowIDs.append(experienceId?.intValue)
    }

    // swiftlint:disable:next function_parameter_count
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    ) {
        states.append(stepState)
        stepIDs.append(stepId.intValue)
        positions.append(step?.intValue)
        totals.append(totalSteps?.intValue)
    }
}
