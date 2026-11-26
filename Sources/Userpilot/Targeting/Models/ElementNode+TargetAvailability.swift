//
//  ElementNode+TargetAvailability.swift
//  Userpilot SDK
//
//  Created by Userpilot on 04/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Tooltip target alerts. Decides whether a match is on the visible screen and why
//  an on-screen winner cannot anchor a tooltip (not visible or overlapped).
//  Main-thread only.
//
//  The resolver owns matching; this file only names the problem with a match, so
//  the issue sent in `mobile_content_error` tells authors what to fix.
//

import UIKit

internal extension ElementNode {

    /// Whether this match is on the visible screen: it has a size and its middle is
    /// inside the part left visible by the safe area and clipping ancestors. Its edges
    /// may be cut off.
    ///
    /// The native capture already gives no selector to a view whose middle is outside the
    /// safe area. This applies the same rule to every strategy, so a wrapper element that
    /// is only partly visible is not there yet rather than a target.
    var isOnVisibleScreen: Bool {
        !bounds.isEmpty && isCentreInView
    }

    /// Why this unique on-screen winner cannot anchor a tooltip, or `nil` when it can.
    ///
    /// Checked in order and the first problem wins: the target cannot be seen, or an
    /// opaque view drawn above covers its middle.
    func unavailableReason(matchCount: Int) -> TargetResolutionError? {
        if isNotVisible { return .notVisible(matchCount: matchCount) }
        if isCovered { return .overlapped(matchCount: matchCount) }
        return nil
    }

    fileprivate var centre: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    /// Effectively transparent through its own view, an ancestor, its web page (`opacity`),
    /// or (for a web or wrapper element) its hosting view. A hosting view the app hid has
    /// the same answer.
    fileprivate var isNotVisible: Bool {
        isTransparent || (view ?? ownershipView)?.userpilotIsHiddenOrTransparent == true
    }

    /// The centre is inside the part left visible by the safe area and clipping ancestors,
    /// for example not scrolled out of a smaller scroll view. A logical element without
    /// visible bounds is trusted.
    fileprivate var isCentreInView: Bool {
        guard let visibleBounds else { return view == nil }
        return visibleBounds.contains(centre)
    }

    /// An opaque view drawn above the target, or above a logical element's host, hides its centre.
    ///
    /// A SwiftUI target marker sits behind its own content by design, so that content
    /// would look like a cover; it is never reported as overlapped.
    fileprivate var isCovered: Bool {
        if view is UserpilotTargetView { return false }
        return (view ?? ownershipView)?.userpilotIsCovered(at: centre) == true
    }
}
