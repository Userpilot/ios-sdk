//
//  FlowStepTarget.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines the element a Flow tooltip step points at and its mapping to the
//  internal tooltip targeting the renderer resolves.
//

import Foundation

// MARK: - FlowStepTarget

/// The element a Flow tooltip step points at, already narrowed by the server to the user's OS.
///
/// `selector` is the flat map of SDK selector keys the Builder captured. Its values are strings
/// or numbers on the wire, so they stay raw here and `toStepTargeting()` turns them into the
/// string identities the targeting strategy matches.
internal struct FlowStepTarget: Codable {
    /// Decoded, not read. Matching uses `selector` only.
    let targetClass: String?

    /// Decoded, not read. Host text never takes part in matching.
    let targetText: String?

    /// Required on a tooltip step: a tooltip step whose target is `null`, or whose selector is missing, `null`,
    /// empty or holds only null or nested values, rejects the whole Flow in `Step`'s decoder, like an unknown
    /// enum value. Other step types don't read it, so an explicit `null` there decodes.
    let selector: [String: AnyCodable]?

    /// Decoded, not read. The capture-time frame, in points.
    let bounds: FlowStepTargetBounds?

    private enum CodingKeys: String, CodingKey {
        case selector, bounds
        case targetClass = "target_class"
        case targetText = "target_text"
    }

    /// Whether a selector value maps to an identity `toStepTargeting()` keeps; only null or nested values don't.
    var hasSelectorIdentity: Bool {
        selector?.values.contains { $0.selectorIdentity != nil } == true
    }

    /// The internal targeting the tooltip renderer resolves: a version-1 `ElementSelector` over the
    /// flat selector. Numbers and booleans become their text (`42`, `true`), so they compare with the
    /// captured string identity. Nested or null values carry no identity and are left out.
    func toStepTargeting() -> StepTargeting {
        StepTargeting(
            selector: ElementSelector(
                properties: (selector ?? [:]).mapValues(\.selectorIdentity),
                selectorVersion: ElementSelector.supportedVersion
            )
        )
    }
}

// MARK: - FlowStepTargetBounds

/// The target's frame at capture time, in points. The wire keys are `x`, `y`, `width` and `height`.
internal struct FlowStepTargetBounds: Codable, Equatable {
    let posX: Double?
    let posY: Double?
    let width: Double?
    let height: Double?

    private enum CodingKeys: String, CodingKey {
        case posX = "x"
        case posY = "y"
        case width, height
    }
}
