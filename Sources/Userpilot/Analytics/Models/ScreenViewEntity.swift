//
//  ScreenViewEntity.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 24/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [ScreenViewEntity]
//  The `ScreenViewEntity` class represents the state and behavior associated with a screen view
//  in the Userpilot SDK. It tracks the current event, handles fake reload logic, manages seen
//  experiences, and provides utility methods to update and reset its state.
//

import Foundation

/// Represents the state and behavior of a screen view in the Userpilot SDK.
internal class ScreenViewEntity {
    /// The current event associated with the screen view.
    var event: Event

    /// A set of IDs representing the experiences seen during this screen view.
    var seenExperiences: Set<Int>
    var seenSurveys: Set<Int>

    /// Initializes a new `ScreenViewEntity` instance.
    ///
    /// - Parameters:
    ///   - event: The current event associated with the screen view.
    ///   - fakeReload: A flag indicating if the screen view was triggered by a fake reload event. Defaults to `false`.
    ///   - seenExperiences: A set of IDs representing seen experiences. Defaults to an empty set.
    ///   - didTriggerEvent: A flag indicating whether an event was triggered during the screen view.
    ///    Defaults to `false`.
    init(event: Event, seenExperiences: Set<Int> = [], seenSurveys: Set<Int> = []) {
        self.event = event
        self.seenExperiences = seenExperiences
        self.seenSurveys = seenSurveys
    }

    /// Resets the state of the screen view entity.
    func resetState() {
        seenExperiences.removeAll()
        seenSurveys.removeAll()
    }

    /// Adds an experience ID to the set of seen experiences.
    func updateSeenFlowExperiences(_ experienceId: Int) {
        seenExperiences.insert(experienceId)
    }

    /// Adds an experience ID to the set of seen experiences.
    func updateSeenSurveyExperiences(_ experienceId: Int) {
        seenSurveys.insert(experienceId)
    }
}
