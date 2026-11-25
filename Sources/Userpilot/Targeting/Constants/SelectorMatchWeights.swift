//
//  SelectorMatchWeights.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines exact-match scoring weights shared by targeting and diagnostics.
//

/// Weight per identity property. Higher means more distinct.
///
/// An explicit Userpilot ID outweighs every other property combined.
internal enum SelectorMatchWeights {
    /// Explicit SwiftUI identity set by `.userpilotTarget(_:)`.
    static let userpilotID = 20_000

    /// `UIView.accessibilityIdentifier`, the strongest UIKit identity.
    static let accessibilityIdentifier = 10_000

    /// SDK-generated identity for views the host cannot tag at all — today
    /// only `tab[N]` for `UITabBarButton`.
    static let autoTag = 5_000

    /// `UIView.tag`. Weak identity: an integer, frequently reused.
    static let tag = 1_000

    /// `UIView.accessibilityLabel`. Weakest: user-visible copy, so it changes
    /// with translations and product wording.
    static let accessibilityLabel = 100

    /// Maximum without `userpilot_id` (16,100), below the explicit ID's weight.
    static let maxWithoutUserpilotID =
        accessibilityIdentifier + autoTag + tag + accessibilityLabel
}
