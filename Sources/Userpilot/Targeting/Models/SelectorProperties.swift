//
//  SelectorProperties.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines SelectorProperties and its related feature models.
//

import Foundation

// MARK: - Selector Properties

/// The five identity properties used by the native targeting strategy.
///
/// One type serves both sides of a match: the target
/// side is inflated from the step property map, and the candidate side is read off a
/// live `UIView` during the traversal. `score(against:)` is therefore
/// symmetric, and there is only ever one weight table.
internal final class SelectorProperties: UserpilotElementSelector, Equatable {

    func toMap() -> [String: String] {
        [SelectorKeys.userpilotID.rawValue: userpilotID,
         ElementPropertyKeys.accessibilityIdentifier.rawValue: accessibilityIdentifier,
         SelectorKeys.autoTag.rawValue: autoTag,
         SelectorKeys.tag.rawValue: tag,
         ElementPropertyKeys.accessibilityLabel.rawValue: accessibilityLabel].compactMapValues { $0 }
    }

    func evaluateMatch(_ target: UserpilotElementSelector) -> Int {
        guard let native = target as? SelectorProperties else { return 0 }
        return score(against: native)
    }

    static func == (lhs: SelectorProperties, rhs: SelectorProperties) -> Bool {
        lhs.toMap() == rhs.toMap()
    }

    /// Explicit Userpilot id, set by `.userpilotTarget(_:)` (or `data-userpilot-id` on a web element);
    /// never by `.userpilotLabel(_:)`.
    let userpilotID: String?

    /// `UIView.accessibilityIdentifier`.
    let accessibilityIdentifier: String?

    /// SDK-generated tag for untaggable views (`tab[N]`).
    let autoTag: String?

    /// `UIView.tag`, stringified. `nil` when the tag is 0 (UIKit's unset default).
    let tag: String?

    /// `UIView.accessibilityLabel`.
    let accessibilityLabel: String?

    /// `true` when no identity property is set, which makes the selector unusable.
    ///
    /// The resolver reports an empty property set as `invalidSelector`.
    var isEmpty: Bool {
        userpilotID == nil
            && accessibilityIdentifier == nil
            && autoTag == nil
            && tag == nil
            && accessibilityLabel == nil
    }

    /// Builds a property set, coercing empty strings to `nil`.
    ///
    /// An empty string is not a valid identity: it would match every other view
    /// that also has an empty value for that property, manufacturing ambiguity.
    /// Empty values are coerced for that reason.
    init(
        userpilotID: String? = nil,
        accessibilityIdentifier: String? = nil,
        autoTag: String? = nil,
        tag: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.userpilotID = Self.normalized(userpilotID)
        self.accessibilityIdentifier = Self.normalized(accessibilityIdentifier)
        self.autoTag = Self.normalized(autoTag)
        self.tag = Self.normalized(tag)
        self.accessibilityLabel = Self.normalized(accessibilityLabel)
    }

    // MARK: Scoring

    /// Scores how well this property set matches `candidate`.
    ///
    /// Exact equality only, and matched weights **sum** — a view matching both
    /// `userpilot_id` and `accessibility_identifier` scores 30,000, which is how
    /// partial matches stay comparable against fuller ones. A property that is
    /// `nil` on either side contributes nothing rather than counting as a match,
    /// so two views that are both missing a property are not thereby "equal" on it.
    ///
    /// - Returns: the summed weight; `0` means no match at all.
    func score(against candidate: SelectorProperties) -> Int {
        var weight = 0

        if let userpilotID, userpilotID == candidate.userpilotID {
            weight += SelectorMatchWeights.userpilotID
        }

        if let accessibilityIdentifier,
           accessibilityIdentifier == candidate.accessibilityIdentifier {
            weight += SelectorMatchWeights.accessibilityIdentifier
        }

        if let autoTag, autoTag == candidate.autoTag {
            weight += SelectorMatchWeights.autoTag
        }

        if let tag, tag == candidate.tag {
            weight += SelectorMatchWeights.tag
        }

        if let accessibilityLabel,
           accessibilityLabel == candidate.accessibilityLabel {
            weight += SelectorMatchWeights.accessibilityLabel
        }

        return weight
    }

    // MARK: Display

    /// Human-readable name for this element, used by capture UI and logs.
    ///
    /// Preference order follows the weight table, so the most distinct available
    /// identity is what an operator sees.
    func displayName(nativeType: String) -> String? {
        if let userpilotID { return userpilotID }
        if let accessibilityIdentifier { return accessibilityIdentifier }
        if let autoTag { return autoTag }
        if let tag { return "\(nativeType) (tag \(tag))" }
        if let accessibilityLabel { return "\(nativeType) (\(accessibilityLabel))" }
        return nil
    }

    // MARK: Helpers

    /// Treats an empty string as absent while preserving whitespace identities.
    private static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Codable

extension SelectorProperties: Codable {

    /// Missing/null properties remain optional; malformed values fail decoding.
    /// Empty strings normalize to `nil` and are checked by the resolver.
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SelectorKeys.self)
        let shared = try decoder.container(keyedBy: ElementPropertyKeys.self)
        self.init(
            userpilotID: try container.decodeIfPresent(String.self, forKey: .userpilotID),
            accessibilityIdentifier: try shared.decodeIfPresent(
                String.self, forKey: .accessibilityIdentifier),
            autoTag: try container.decodeIfPresent(String.self, forKey: .autoTag),
            tag: try container.decodeIfPresent(String.self, forKey: .tag),
            accessibilityLabel: try shared.decodeIfPresent(
                String.self, forKey: .accessibilityLabel)
        )
    }

    /// Encodes only the properties that are actually set, for a screen capture's
    /// element tree.
    ///
    /// Uses the decoding keys so Builder captures round-trip into selectors.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SelectorKeys.self)
        var shared = encoder.container(keyedBy: ElementPropertyKeys.self)
        try container.encodeIfPresent(userpilotID, forKey: .userpilotID)
        try shared.encodeIfPresent(
            accessibilityIdentifier, forKey: .accessibilityIdentifier)
        try container.encodeIfPresent(autoTag, forKey: .autoTag)
        try container.encodeIfPresent(tag, forKey: .tag)
        try shared.encodeIfPresent(accessibilityLabel, forKey: .accessibilityLabel)
    }
}
