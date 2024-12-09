//
//  UserpilotExperienceDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This protocol allows the application to observe and respond to changes in the state
//  of Userpilot experiences and individual steps within those experiences.
//

import Foundation

/// The various states of a Userpilot experience.
@objc
public enum UserpilotExperienceState: Int {
    /// Indicates that the experience has started.
    case started

    /// Indicates that the experience has been completed successfully.
    case completed

    /// Indicates that the experience was dismissed before completion.
    case dismissed
}

/// A protocol to observe and respond to state changes in Userpilot experiences.
@objc
public protocol UserpilotExperienceDelegate: AnyObject {
    /// Called when the state of a Userpilot experience changes.
    ///
    /// - Parameters:
    ///   - state: The current state of the experience. Possible values are:
    ///     - `.started`: The experience has started.
    ///     - `.completed`: The experience has completed successfully.
    ///     - `.dismissed`: The experience was dismissed before completion.
    ///   - id: A unique identifier for the experience.
    ///   - experienceToken: A token that uniquely identifies the specific instance of the experience.
    func onExperienceStateChanged(state: UserpilotExperienceState, id: Int, experienceToken: String)

    /// Called when the state of a specific step within a Userpilot experience changes.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the experience.
    ///   - experienceToken: A token that uniquely identifies the specific instance of the experience.
    ///   - step: The current step number in the experience.
    ///   - totalSteps: The total number of steps in the experience.
    func onExperienceStepStateChanged(id: Int, experienceToken: String, step: Int, totalSteps: Int)
}
