//
//  UPOverlayVisibility.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  How many Userpilot overlay windows are on screen, and a signal for when that changes.
//
//  Two Userpilot instances — a host app plus an embedded vendor SDK — each own their own overlay
//  window. Two large glass surfaces stacked one behind the other produce exactly the layered-glass
//  appearance Apple warns against ("Avoid crowding or layering Liquid Glass elements on top of each
//  other"), and neither instance can see the other's UI to avoid it. So the count is process-wide
//  while the decision it feeds stays per-instance.
//
//  Process-wide state, deliberately: the windows belong to different instances, and the question
//  "how many are visible" has no per-instance answer.
//

import UIKit

internal enum UPOverlayVisibility {

    /// Posted after the number of visible overlay windows changes.
    ///
    /// A presented sheet, dialog or full-screen experience observes this and re-resolves its
    /// appearance, so a surface that was glass when it appeared turns solid when a second overlay
    /// joins it — and back again when that one leaves.
    static let didChangeNotification = Notification.Name("com.userpilot.overlayVisibilityDidChange")

    /// The number of visible overlay windows, counted from the window hierarchy.
    ///
    /// Counted on demand rather than tracked incrementally: `isHidden` is set from several places in
    /// the window's own lifecycle, and a count derived from the hierarchy cannot drift out of step
    /// with it the way a manually maintained tally can.
    static var visibleCount: Int {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { $0 is ExperienceOverlayWindow && !$0.isHidden }
            .count
    }

    /// Announces a visibility change, if the count actually moved.
    ///
    /// Called by `ExperienceOverlayWindow` as it shows and hides. Comparing against the last
    /// published value is what keeps a presented experience from re-resolving its whole appearance
    /// on every window operation that leaves the count alone.
    ///
    /// Always delivered on the main thread, because every subscriber reacts by touching UIKit.
    static func overlayVisibilityMayHaveChanged() {
        let count = visibleCount
        guard count != lastPublishedCount else { return }
        lastPublishedCount = count

        let post = {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }

    private static var lastPublishedCount = 0

    #if DEBUG
    /// Clears the published count so tests do not inherit a tally from an earlier case.
    static func resetForTesting() {
        lastPublishedCount = 0
    }
    #endif
}
