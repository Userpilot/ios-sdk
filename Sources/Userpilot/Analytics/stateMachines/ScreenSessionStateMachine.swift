//
//  ScreenSessionStateMachine.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 24/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [ScreenSessionStateMachine]
//  Tracks the current screen event and the content seen during that screen session.
//

import Foundation

/// Holds screen-session state used when publishing screen and fake-reload events.
internal class ScreenSessionStateMachine {
    /// The current event associated with the screen view.
    var event: Event

    /// IDs for flow and survey experiences seen during this screen session.
    var seenExperiences: Set<Int>
    var seenSurveys: Set<Int>

    /// Initializes a new `ScreenSessionStateMachine` instance.
    ///
    /// - Parameters:
    ///   - event: The current event associated with the screen view.
    ///   - seenExperiences: A set of IDs representing seen experiences. Defaults to an empty set.
    ///   - seenSurveys: A set of IDs representing seen surveys. Defaults to an empty set.
    init(event: Event, seenExperiences: Set<Int> = [], seenSurveys: Set<Int> = []) {
        self.event = event
        self.seenExperiences = seenExperiences
        self.seenSurveys = seenSurveys
    }

    /// Clears tracked content for the active screen session.
    func resetState() {
        seenExperiences.removeAll()
        seenSurveys.removeAll()
    }

    /// Adds a flow experience ID to the seen set.
    func updateSeenFlowExperiences(_ experienceId: Int) {
        seenExperiences.insert(experienceId)
    }

    /// Adds a survey experience ID to the seen set.
    func updateSeenSurveyExperiences(_ experienceId: Int) {
        seenSurveys.insert(experienceId)
    }
}
