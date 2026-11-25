//
//  FlowStep.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines authored flow steps and their sections.
//

import Foundation
import UIKit

// MARK: - Step

/// One authored step: its sections and button action, plus, for a Flow step, its place, type, settings and target.
internal struct Step: Codable {
    let id: Int
    let order: Int
    let sections: [Section]
    let buttonAction: ButtonAction?
    let mobileTheme: ExperienceTheme?

    /// Which element a tooltip segment's step points at. Render config set only by the `FlowWalk` projection
    /// from `target`; never decoded, so a payload's `targeting` key is ignored.
    let targeting: StepTargeting?

    /// How a tooltip segment's step is drawn relative to its target, built like `targeting` from `settings`.
    let presentation: StepPresentation?

    /// 1-based place among all of the Flow's steps, compared with `FlowContent.stepsCount`.
    /// Flow steps only; like every Flow key below, optional so other payloads keep decoding.
    let position: Int?

    /// Which presenter shows this Flow step. An unknown value rejects the whole Flow.
    let stepType: FlowStepType?

    /// Placement, advance, fallback, dismissal and backdrop for this Flow step.
    let settings: FlowStepSettings?

    /// The element a Flow tooltip step points at, for the user's OS. `nil` on modal and slideout steps.
    let target: FlowStepTarget?

    private enum CodingKeys: String, CodingKey {
        case id, order, sections
        case buttonAction = "button_action"
        case mobileTheme = "theme_data"
        case position
        case stepType = "step_type"
        case settings
        case target
    }

    /// Builds a step directly, for fixtures and internal callers.
    ///
    /// Declared explicitly rather than relying on the synthesized memberwise
    /// initialiser: Swift gives a default argument to an optional stored
    /// property only when it is a `var`, and every property here is `let` on a
    /// decoded model. Without this, adding the tooltip-only `targeting` and
    /// `presentation` fields would force every existing call site to pass two
    /// `nil`s for fields its presentation type does not have.
    init(
        id: Int,
        order: Int,
        sections: [Section],
        buttonAction: ButtonAction?,
        mobileTheme: ExperienceTheme?,
        targeting: StepTargeting? = nil,
        presentation: StepPresentation? = nil,
        position: Int? = nil,
        stepType: FlowStepType? = nil,
        settings: FlowStepSettings? = nil,
        target: FlowStepTarget? = nil
    ) {
        self.id = id
        self.order = order
        self.sections = sections
        self.buttonAction = buttonAction
        self.mobileTheme = mobileTheme
        self.targeting = targeting
        self.presentation = presentation
        self.position = position
        self.stepType = stepType
        self.settings = settings
        self.target = target
    }
}

extension Step {

    /// Decodes every wire key as the synthesized decoder would, then rejects a tooltip step whose `target`
    /// has no selector identity: missing, null, empty, or only null or nested values. The throw drops the
    /// whole Flow candidate, like an unknown enum value. Steps of other types need no target. A preview
    /// response skips the rule (`PreviewExperience.decode(from:)`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stepType = try container.decodeIfPresent(FlowStepType.self, forKey: .stepType)
        let target = try container.decodeIfPresent(FlowStepTarget.self, forKey: .target)
        if stepType == .tooltip, !decoder.decodesPreviewContent, target?.hasSelectorIdentity != true {
            throw DecodingError.dataCorruptedError(
                forKey: .target, in: container, debugDescription: "Tooltip step needs a non-empty selector"
            )
        }
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            order: try container.decode(Int.self, forKey: .order),
            sections: try container.decode([Section].self, forKey: .sections),
            buttonAction: try container.decodeIfPresent(ButtonAction.self, forKey: .buttonAction),
            mobileTheme: try container.decodeIfPresent(ExperienceTheme.self, forKey: .mobileTheme),
            position: try container.decodeIfPresent(Int.self, forKey: .position),
            stepType: stepType,
            settings: try container.decodeIfPresent(FlowStepSettings.self, forKey: .settings),
            target: target
        )
    }
}

internal extension Step {

    /// `position` is at least 1, and at most `stepsCount` when the Flow sends one.
    func hasValidPosition(stepsCount: Int?) -> Bool {
        guard let position, position >= 1 else { return false }
        return stepsCount.map { position <= $0 } ?? true
    }

    /// This step's host callback for `state`, numbered by its own `position` among the Flow's `steps_count`.
    func callback(_ state: UserpilotExperienceState, _ stepsCount: Int) -> ExperienceCallback {
        .stepState(state, stepId: id, position: position, stepsCount: stepsCount)
    }

    /// Gap, edge margin and highlight are the renderer's fixed `Constants.Theme` tooltip values, never backend
    /// values, and the pointer is always off. The step's `settings.backdrop` reaches the dim through its merged
    /// theme only. A `target_tap` step advances on its target and renders no button line, even when the payload
    /// sends one.
    func asTooltipStep() -> Step {
        let advancesOnTarget = settings?.advanceOn == .targetTap
        let presentation = StepPresentation(
            preferredPlacement: settings?.position?.tooltipPlacement,
            pointer: TooltipPointer(enabled: false),
            targetTapAction: advancesOnTarget ? "next" : nil
        )
        return Step(
            id: id,
            order: order,
            sections: advancesOnTarget ? sections.withoutButtonLines() : sections,
            buttonAction: buttonAction,
            mobileTheme: mobileTheme,
            targeting: target?.toStepTargeting(),
            presentation: presentation,
            position: position,
            stepType: stepType,
            settings: settings,
            target: target
        )
    }
}

// MARK: - Section

internal struct Section: Codable {
    let lines: [Line]
}

internal extension Array where Element == Section {
    /// The sections without their button lines; a section left with no lines is dropped.
    func withoutButtonLines() -> [Section] {
        map { Section(lines: $0.lines.filter { $0.type != .button }) }
            .filter { !$0.lines.isEmpty }
    }
}
