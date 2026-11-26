//
//  UserpilotElementTargetingStrategy.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Provides per-instance native or wrapper layout and screenshot capture.
//

import UIKit

/// Configure through `Userpilot.Config.elementTargetingStrategy(_:)` before initialization.
/// Calls run on main. Use only the supplied host; do not select another window or SDK instance.
@objc public protocol UserpilotElementTargetingStrategy: AnyObject {
    /// Full host hierarchy in window-coordinate points, independently of autocapture options.
    /// Logical wrapper nodes keep their own bounds and a weak ownership view for their native host.
    /// Complete exactly once on main; asynchronous bridge work must not block the UI.
    func captureLayout(in rootView: UIView, completion: @escaping (ElementNode?) -> Void)

    /// Returns nil when the properties cannot identify an element in this strategy.
    func inflateSelector(from properties: [String: String]) -> UserpilotElementSelector?

    /// Optional screenshot with the logical size and insets used by the captured tree.
    /// Its origin must match the supplied host. Nil uses native capture.
    @objc optional func captureScreenshot(in window: UIWindow) -> UserpilotScreenshot?

    /// Optional answer to whether the screen is at its end: its main vertical scroll area
    /// cannot scroll further down, or nothing visible scrolls vertically. A tooltip whose
    /// target is not found reports `not_found` only at the end of the screen.
    ///
    /// Implement it when the native views cannot see the scroll position, for example when
    /// the UI draws into one native view. Complete exactly once on main with a boolean
    /// `NSNumber`, or nil to use native detection.
    @objc optional func isScrolledToEnd(in rootView: UIView, completion: @escaping (NSNumber?) -> Void)
}

/// Default strategy for UIKit and SwiftUI; the resolver owns host admission and ownership checks.
internal final class NativeElementTargetingStrategy: UserpilotElementTargetingStrategy {
    func captureLayout(in rootView: UIView, completion: @escaping (ElementNode?) -> Void) {
        guard let tree = rootView.userpilotElementNode() else { completion(nil); return }
        tree.captureWebElements { completion($0) }
    }

    func inflateSelector(from properties: [String: String]) -> UserpilotElementSelector? {
        let selector = SelectorProperties(
            userpilotID: properties[SelectorKeys.userpilotID.rawValue],
            accessibilityIdentifier: properties[ElementPropertyKeys.accessibilityIdentifier.rawValue],
            autoTag: properties[SelectorKeys.autoTag.rawValue],
            tag: properties[SelectorKeys.tag.rawValue],
            accessibilityLabel: properties[ElementPropertyKeys.accessibilityLabel.rawValue]
        )
        return selector.isEmpty ? nil : selector
    }
}
