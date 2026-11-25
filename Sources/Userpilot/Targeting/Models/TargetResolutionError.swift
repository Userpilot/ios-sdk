//
//  TargetResolutionError.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines TargetResolutionError and its related feature models.
//

import UIKit

// MARK: - Resolution Error

/// Why a selector failed to resolve to exactly one live view.
internal enum TargetResolutionError: Error {

    /// The selector carries no identity properties at all, so nothing could ever
    /// match it. An authoring or backend bug.
    case invalidSelector

    /// The selector declares a scoring version this SDK does not implement.
    ///
    /// Rejected rather than scored with today's weights: mis-scoring would
    /// silently resolve to the wrong view, which is worse than not showing the
    /// tooltip.
    case unsupportedSelectorVersion(Int)

    /// The admitted host is invalid or its view tree could not be read.
    case layoutUnavailable

    /// No view scored above zero, none cleared `minimum_score`, or no match has a size
    /// and its middle on the visible screen. A hidden target counts as not found.
    case notFound

    /// Several views tied at the top score, so no single view is *the* target.
    ///
    /// Always a failure, never resolved by picking the first — see
    /// `ElementSelector.onAmbiguous`.
    case ambiguous(matchCount: Int)

    /// The target is on the visible screen but cannot be seen: it, an ancestor, its web
    /// page styling or (for a web or wrapper element) its hosting view makes it effectively
    /// transparent.
    case notVisible(matchCount: Int)

    /// The target is on screen, but an opaque view drawn above it covers its centre.
    case overlapped(matchCount: Int)

    /// The selector was authored against a different screen than the one on
    /// display.
    ///
    /// Reserved result: `constraints.screen_name` is decoded but not evaluated.
    /// Content screen gating happens before the tooltip step is evaluated.
    case screenMismatch

    /// A target that *was* resolved and visible has gone away.
    ///
    /// Distinct from `notFound`, which means it was never there. Only this case
    /// dismisses a visible tooltip, and only after re-resolution also fails.
    case targetLost

    /// Whether an immediate retry, inside the step's retry ladder, could succeed.
    ///
    /// Invalid identity, unsupported versions and screen mismatches cannot be
    /// fixed by retrying the same selector against the same host.
    var isRetryable: Bool {
        switch self {
        case .invalidSelector, .unsupportedSelectorVersion, .screenMismatch:
            return false
        case .layoutUnavailable, .notFound, .ambiguous, .notVisible, .overlapped, .targetLost:
            return true
        }
    }

    /// Whether to park for scroll recovery after immediate retries are exhausted.
    ///
    /// Scrolling may expose a missing/clipped target or separate tied candidates.
    /// `layoutUnavailable` can retry immediately but cannot park: there is no
    /// readable host from which to receive a useful scroll signal.
    var isRecoverable: Bool {
        switch self {
        case .notFound, .notVisible, .overlapped, .ambiguous, .targetLost:
            return true
        case .invalidSelector, .unsupportedSelectorVersion, .layoutUnavailable,
             .screenMismatch:
            return false
        }
    }

    /// Short, stable identifier for analytics and logs.
    ///
    /// Never includes selector values, view hierarchies, or host-app text — only
    /// the shape of the failure. Selector contents are host-app data and must
    /// not leave the device in an operational event.
    var reason: String {
        switch self {
        case .invalidSelector: return "invalid_selector"
        case .unsupportedSelectorVersion: return "unsupported_selector_version"
        case .layoutUnavailable: return "layout_unavailable"
        case .notFound: return "not_found"
        case .ambiguous: return "ambiguous"
        case .notVisible: return "not_visible"
        case .overlapped: return "overlapped"
        case .screenMismatch: return "screen_mismatch"
        case .targetLost: return "target_lost"
        }
    }

    /// How many views the selector matched, when that is meaningful: every candidate
    /// that cleared `minimum_score`, not just the tied ones. Diagnostics only (the SDK
    /// log): it tells a target that exists but cannot be used from one that matched
    /// nothing, and is never sent on an event.
    var matchCount: Int {
        switch self {
        case let .ambiguous(matchCount), let .notVisible(matchCount), let .overlapped(matchCount):
            return matchCount
        default: return 0
        }
    }
}
