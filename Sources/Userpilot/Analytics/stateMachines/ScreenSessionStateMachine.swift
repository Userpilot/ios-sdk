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
/// Seen-content reads, updates, and resets run synchronously on a private serial queue.
internal class ScreenSessionStateMachine {
    /// The current event associated with the screen view.
    let event: Event

    private let queue = DispatchQueue(label: Constants.DispatchQueues.screenSessionState)
    private var storedSeenExperiences: Set<Int>
    private var storedSeenSurveys: Set<Int>

    /// IDs for flow and survey experiences seen during this screen session.
    var seenExperiences: Set<Int> {
        queue.sync { storedSeenExperiences }
    }

    var seenSurveys: Set<Int> {
        queue.sync { storedSeenSurveys }
    }

    /// Initializes a new `ScreenSessionStateMachine` instance.
    ///
    /// - Parameters:
    ///   - event: The current event associated with the screen view.
    ///   - seenExperiences: A set of IDs representing seen experiences. Defaults to an empty set.
    ///   - seenSurveys: A set of IDs representing seen surveys. Defaults to an empty set.
    init(event: Event, seenExperiences: Set<Int> = [], seenSurveys: Set<Int> = []) {
        self.event = event
        self.storedSeenExperiences = seenExperiences
        self.storedSeenSurveys = seenSurveys
    }

    /// Clears tracked content for the active screen session.
    func resetState() {
        queue.sync {
            storedSeenExperiences.removeAll()
            storedSeenSurveys.removeAll()
        }
    }

    /// Adds a flow experience ID to the seen set.
    func updateSeenFlowExperiences(_ experienceId: Int) {
        _ = queue.sync { storedSeenExperiences.insert(experienceId) }
    }

    /// Adds a survey experience ID to the seen set.
    func updateSeenSurveyExperiences(_ experienceId: Int) {
        _ = queue.sync { storedSeenSurveys.insert(experienceId) }
    }
}
