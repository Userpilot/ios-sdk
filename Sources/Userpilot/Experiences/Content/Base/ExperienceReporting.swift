//
//  ExperienceReporting.swift
//  Userpilot SDK
//
//  Created by Userpilot on 23/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Fires an experience view model's host callbacks and logs, then publishes its backend events.
//

import Foundation

/// A view model whose host callbacks and logs carry its experience type and id.
internal protocol ExperienceReporting: BaseExperienceViewModel {
    var experienceType: UserpilotExperienceType { get }
    /// NPS has none.
    var experienceID: Int? { get }
}

extension ExperienceReporting {

    /// Fires the report's host callbacks, then publishes its events.
    func report(_ report: ExperienceReport) {
        notifyHost(report.callbacks)
        report.events.forEach { publishEvent($0) }
    }

    /// Fires each callback through the delegate, then logs it.
    func notifyHost(_ callbacks: [ExperienceCallback]) {
        for callback in callbacks {
            switch callback {
            case .experienceState(let state):
                notifyExperienceState(state)
            case let .stepState(state, stepId, position, stepsCount):
                notifyStepState(state, stepId: stepId, position: position, stepsCount: stepsCount)
            }
        }
    }

    private func notifyExperienceState(_ state: UserpilotExperienceState) {
        userpilot?.experienceDelegate?.onExperienceStateChanged(
            experienceType: experienceType,
            experienceId: experienceID.map { NSNumber(value: $0) },
            experienceState: state
        )
        logExperience(state)
    }

    /// Only an experience with an id has steps.
    private func notifyStepState(_ state: UserpilotExperienceState, stepId: Int, position: Int?, stepsCount: Int?) {
        guard let experienceID else { return }
        userpilot?.experienceDelegate?.onExperienceStepStateChanged(
            experienceType: experienceType,
            experienceId: NSNumber(value: experienceID),
            stepId: NSNumber(value: stepId),
            stepState: state,
            step: position.map { NSNumber(value: $0) },
            totalSteps: stepsCount.map { NSNumber(value: $0) }
        )
        logStep(state, experienceID: experienceID, stepId: stepId, position: position, stepsCount: stepsCount)
    }

    // MARK: - Logging

    private func logExperience(_ state: UserpilotExperienceState) {
        guard let experienceID else {
            logger.info(
                "🌠 Userpilot experience -> type: %{public}@, state: %{public}@",
                experienceType.rawValueString,
                state.rawValueString
            )
            return
        }
        logger.info(
            "🌠 Userpilot experience -> type: %{public}@, experienceId: %{public}@, state: %{public}@",
            experienceType.rawValueString,
            String(experienceID),
            state.rawValueString
        )
    }

    /// A Flow step logs its `position` (`nil` when unset) and `steps_count`; a survey step logs neither.
    private func logStep(
        _ state: UserpilotExperienceState,
        experienceID: Int,
        stepId: Int,
        position: Int?,
        stepsCount: Int?
    ) {
        guard let stepsCount else {
            logger.info(
                // swiftlint:disable:next line_length
                "🌠 Userpilot experience step -> type: %{public}@, experienceId: %{public}@, state: %{public}@, stepId: %{public}@",
                experienceType.rawValueString,
                String(experienceID),
                state.rawValueString,
                String(stepId)
            )
            return
        }
        logger.info(
            // swiftlint:disable:next line_length
            "🌠 Userpilot experience step -> type: %{public}@, experienceId: %{public}@, state: %{public}@, stepId: %{public}@, step: %{public}@, totalSteps: %{public}@",
            experienceType.rawValueString,
            String(experienceID),
            state.rawValueString,
            String(stepId),
            position.map { String($0) } ?? "nil",
            String(stepsCount)
        )
    }
}
