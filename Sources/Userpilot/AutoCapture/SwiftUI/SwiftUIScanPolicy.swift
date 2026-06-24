//
//  SwiftUIScanPolicy.swift
//  Userpilot
//
//  Per-screen opt-out for the accessibility-tree read (the resolver's Stage A
//  and the scan's accessibility pass).
//
//  Some SwiftUI screens — specifically nested LazyVStack / LazyHStack that
//  mutate state inside `.onAppear` — can livelock the layout engine while the
//  accessibility tree is being traversed (Apple bug FB21851974). The
//  accessibility path is the only thing that triggers that defect, so a screen
//  can opt out of it while reflection + display-list capture keep working.
//
//  The opt-out is stored as an associated object on the hosting
//  `UIViewController`, so it lives and dies with that view controller instance
//  — no central registry, no `ObjectIdentifier` reuse hazard, nothing to clean
//  up on dismissal.
//

import UIKit
import ObjectiveC.runtime

internal enum SwiftUIScanPolicy {

    // Address-only token used as the associated-object key.
    private static var skipAccessibilityKey: UInt8 = 0

    /// Opt `viewController` out of the accessibility-tree read for its lifetime.
    static func skipAccessibility(for viewController: UIViewController) {
        objc_setAssociatedObject(
            viewController,
            &skipAccessibilityKey,
            NSNumber(value: true),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// Re-enable the accessibility read for `viewController` (rarely needed).
    static func allowAccessibility(for viewController: UIViewController) {
        objc_setAssociatedObject(
            viewController,
            &skipAccessibilityKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// True when `viewController` has opted out of the accessibility-tree read.
    static func shouldSkipAccessibility(_ viewController: UIViewController) -> Bool {
        (objc_getAssociatedObject(viewController, &skipAccessibilityKey) as? NSNumber)?.boolValue ?? false
    }
}
