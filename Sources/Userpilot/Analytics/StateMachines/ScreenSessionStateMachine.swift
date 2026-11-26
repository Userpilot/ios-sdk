//
//  ScreenSessionStateMachine.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [ScreenSessionStateMachine]
//  Tracks the current screen event and the content seen during that screen session.
//

import Foundation

/// Holds screen-session state used when publishing screen and fake-reload events.
/// Seen-content reads, updates, and resets run synchronously on a private serial queue.
internal final class ScreenSessionStateMachine {
    /// The current event associated with the screen view.
    let event: Event

    /// Original screen metadata, independent of seen content and session configuration.
    var screenPayload: ScreenPayload { ScreenPayload(event: event) }

    private let queue = DispatchQueue(label: Constants.Analytics.screenSessionQueueLabel)
    private var storedSeenExperiences: Set<Int>
    private var storedSeenSurveys: Set<Int>
    private var storedFlowSeenContent: Set<Int>

    /// IDs for flow and survey experiences seen during this screen session.
    var seenExperiences: Set<Int> {
        queue.sync { storedSeenExperiences }
    }

    var seenSurveys: Set<Int> {
        queue.sync { storedSeenSurveys }
    }

    /// Flow step IDs shown during this screen session. They have no wire key of their own;
    /// they go out merged into `seen_contents`.
    var flowSeenContent: Set<Int> {
        queue.sync { storedFlowSeenContent }
    }

    /// Initializes a new `ScreenSessionStateMachine` instance.
    ///
    /// - Parameters:
    ///   - event: The current event associated with the screen view.
    ///   - seenExperiences: A set of IDs representing seen experiences. Defaults to an empty set.
    ///   - seenSurveys: A set of IDs representing seen surveys. Defaults to an empty set.
    ///   - flowSeenContent: A set of shown Flow step IDs. Defaults to an empty set.
    init(event: Event, seenExperiences: Set<Int> = [], seenSurveys: Set<Int> = [], flowSeenContent: Set<Int> = []) {
        self.event = event
        self.storedSeenExperiences = seenExperiences
        self.storedSeenSurveys = seenSurveys
        self.storedFlowSeenContent = flowSeenContent
    }

    /// Clears tracked content for the active screen session.
    func resetState() {
        queue.sync {
            storedSeenExperiences.removeAll()
            storedSeenSurveys.removeAll()
            storedFlowSeenContent.removeAll()
        }
    }

    /// Records the content ID in its flow or survey set before returning to the publisher.
    func recordExperiencePublished(_ type: ExperienceType, _ experienceId: Int) {
        if type == .flow {
            updateSeenFlowExperiences(experienceId)
        } else {
            updateSeenSurveyExperiences(experienceId)
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

    /// Records that the Flow step `stepId` was shown during this screen session. Called with the step's
    /// `seen_mobile_content_step`, so a skipped or only received step is never recorded.
    func recordFlowStepSeen(_ stepId: Int) {
        _ = queue.sync { storedFlowSeenContent.insert(stepId) }
    }
}

/// The screen event's `seen_contents`: seen content ids and shown Flow step ids in one de-duplicated set,
/// with no separate wire key for the steps.
internal func mergedSeenContents(seenFlowIds: Set<Int>, flowSeenContent: Set<Int>) -> Set<Int> {
    seenFlowIds.union(flowSeenContent)
}
