//
//  ElementSelector.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Decodes tooltip selectors and scores exact identity matches.
//  The explicit Userpilot ID weighs 20,000; all other properties total 16,100.
//  Weight changes require coordinated schema changes because Builder score
//  floors depend on these values.
//

import Foundation

// MARK: - Element Selector

/// A versioned property map for one target element.
///
/// This is the payload-side type: it arrives decoded from a tooltip step and is
/// handed to `ElementTargeting.resolve(selector:in:)`.
internal struct ElementSelector: Codable {

    /// The only selector version this SDK knows how to score.
    ///
    /// Version and weight changes must stay coordinated with selector producers.
    static let supportedVersion = 1

    /// Scoring contract version. Anything other than `supportedVersion` is
    /// rejected outright rather than scored with today's weights.
    ///
    /// Rejecting unknown versions prevents scoring a selector with the wrong weights.
    let selectorVersion: Int

    /// Platform the selector was authored for (`ios`). Decoded, not evaluated —
    /// content is already platform-gated before it reaches the SDK.
    let platform: String?

    /// UI toolkit the selector was authored against. Decoded for metadata only;
    /// the instance configuration selects its targeting strategy.
    let toolkit: String?

    /// Raw identities; the owning strategy determines their meaning at resolution.
    let properties: [String: String?]

    /// Preserve framework-specific keys, omitting only absent identity values.
    var effectiveProperties: [String: String] { properties.compactMapValues { $0 } }

    /// Builder-side validation hints. See `Constraints`.
    let constraints: Constraints?

    /// Score floor. Candidates scoring below this are discarded **before** the
    /// highest score is taken.
    ///
    /// The Builder supplies this floor so a weak label match (100) cannot satisfy
    /// a selector requiring an accessibility identifier match (10,000).
    let minimumScore: Int?

    /// What the author asked for when several views tie at the top score.
    ///
    /// Decoded but not evaluated. A highest-score tie always reports `ambiguous`
    /// so retries can wait for a unique match without selecting an arbitrary view.
    let onAmbiguous: String?

    /// `true` when this SDK implements the selector's scoring version.
    var isSupportedVersion: Bool {
        selectorVersion == Self.supportedVersion
    }

    private typealias CodingKeys = SelectorKeys.Envelope

    /// Decodes a selector, defaulting an absent `selector_version` to the
    /// supported one.
    ///
    /// A null version also defaults; an explicit unsupported version is rejected.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectorVersion =
            try container.decodeIfPresent(Int.self, forKey: .selectorVersion)
            ?? Self.supportedVersion
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
        self.toolkit = try container.decodeIfPresent(String.self, forKey: .toolkit)
        // Missing/null identities are checked by the resolver. Malformed values
        // propagate to the content decoder so it rejects and logs the payload.
        self.properties =
            try container.decodeIfPresent([String: String?].self, forKey: .properties)
            ?? [:]
        self.constraints = try container.decodeIfPresent(
            Constraints.self, forKey: .constraints)
        self.minimumScore = try container.decodeIfPresent(Int.self, forKey: .minimumScore)
        self.onAmbiguous = try container.decodeIfPresent(String.self, forKey: .onAmbiguous)
    }

    /// Builds a selector directly, for fixtures and internal callers.
    init(
        properties: [String: String?],
        selectorVersion: Int = ElementSelector.supportedVersion,
        platform: String? = nil,
        toolkit: String? = nil,
        constraints: Constraints? = nil,
        minimumScore: Int? = nil,
        onAmbiguous: String? = nil
    ) {
        self.selectorVersion = selectorVersion
        self.platform = platform
        self.toolkit = toolkit
        self.properties = properties
        self.constraints = constraints
        self.minimumScore = minimumScore
        self.onAmbiguous = onAmbiguous
    }

    // MARK: - Constraints

    /// Builder-side validation hints that ride along on the selector.
    ///
    /// Decoded but not evaluated by target resolution. Content screen gating is
    /// handled before the tooltip step is evaluated.
    internal struct Constraints: Equatable {

        /// Semantic role the Builder believed the target had (e.g. `button`).
        let role: String?

        /// Native class name the Builder saw at authoring time.
        let nativeType: String?

        /// Screen the selector was authored against.
        let screenName: String?

    }

}

// MARK: - Codable

extension ElementSelector.Constraints: Codable {
    private typealias CodingKeys = SelectorKeys.Constraints
}
