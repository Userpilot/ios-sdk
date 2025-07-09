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

// swiftlint:disable all

/// The Userpilot experience type.
@objc
public enum UserpilotExperienceType: Int {
    case flow
    case survey
    case nps
}

/// The various states of a Userpilot experience.
@objc
public enum UserpilotExperienceState: Int {
    /// Indicates that the  experience/step has started.
    case started

    /// Indicates that the  experience/step has been completed successfully.
    case completed

    /// Indicates that the  experience/step was dismissed before completion.
    case dismissed

    /// Indicates that the  experience/step was skipped.
    case skipped

    /// Indicates that the experience/step was Submitted.
    case submitted
}

/// A protocol to observe and respond to state changes in Userpilot experiences.
@objc
public protocol UserpilotExperienceDelegate: AnyObject {

    /// Called when the state of a Userpilot experience changes.
    ///
    /// - Parameters:
    ///   - experienceType: The current experience type.
    ///   - experienceId: A unique identifier for the experience.
    ///   - experienceState: The current state of the experience.
    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?, // Optional Int
        experienceState: UserpilotExperienceState
    )

    /// Called when the state of a specific step within a Userpilot experience changes.
    ///
    /// - Parameters:
    ///   - experienceType: The current experience type.
    ///   - experienceId: A unique identifier for the experience.
    ///   - stepId: A unique identifier for the step.
    ///   - stepState: The current state of the step.
    ///   - step: The current step number in the experience.
    ///   - totalSteps: The total number of steps in the experience.
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    )
}

// swiftlint:enable all
