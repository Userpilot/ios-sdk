//
//  UIView+SwiftUITitleCapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Enriches a tapped SwiftUI view with a title while preserving capture privacy and payload keys.
//

// swiftlint:disable identifier_name
// swiftlint:disable:previous blanket_disable_command

import UIKit

internal extension UIView {

    /// Cheap superview-chain check: is this view rendered inside a SwiftUI
    /// hosting view? Used to gate the resolver so it never runs for plain UIKit.
    var up_isInsideHostingView: Bool {
        var current: UIView? = self
        while let view = current {
            if SwiftUIDetection.isHostingView(view) {
                return true
            }
            current = view.superview
        }
        return false
    }

    /// The outermost SwiftUI hosting view containing this view, or `self` outside SwiftUI.
    /// SwiftUI privacy modifiers flag a platform-view host that is often a SIBLING of the
    /// deepest tapped view, so point-scoped flag searches start from here.
    var up_outermostHostingView: UIView {
        var outermost: UIView = self
        var current: UIView? = self
        while let view = current {
            if SwiftUIDetection.isHostingView(view) {
                outermost = view
            }
            current = view.superview
        }
        return outermost
    }

    /// Walks DOWN from `self` through subviews whose frame contains `windowPoint`
    /// (window coordinates), returning the first that has `flag` set. Bounded to
    /// the thin point-containing path, not the whole tree.
    ///
    /// This closes the pure-SwiftUI redact/ignore gap: the policy modifier's
    /// carrier sets its flag on a descendant whose frame contains the tap, which
    /// the SDK's upward responder-chain gate can't see when the tap resolves to
    /// an ancestor hosting view. Identity + geometry match, so it never
    /// over-flags the wrong control and fails safe on overlap.
    func up_flagInSubtree(containing windowPoint: CGPoint, _ flag: KeyPath<UIView, Bool>) -> Bool {
        let local = convert(windowPoint, from: nil)   // `nil` == window space
        guard bounds.contains(local) else { return false }
        if self[keyPath: flag] { return true }
        return subviews.contains { $0.up_flagInSubtree(containing: windowPoint, flag) }
    }

    /// SwiftUI button-title enrichment for a regular window tap on this view. Runs only when
    /// nothing produced a title, and writes `target_text` ONLY — target_class / hierarchy /
    /// accessibility_* are untouched. Ignore at/above the tapped view was already handled by
    /// `shouldIgnoreInteractions()`; this also catches the pure-SwiftUI case where the policy
    /// carrier flag sits on a descendant or a sibling under the tap (which the upward
    /// responder-chain gate can't see). An explicitly ignored tap leaves target_text unset and
    /// skips the scan entirely; a redacted one publishes the redaction placeholder.
    func addSwiftUITitle(
        to properties: inout [String: Any],
        at point: CGPoint,
        in window: UIWindow,
        config: Userpilot.Config
    ) {
        let swiftUIRoot = up_outermostHostingView
        guard properties[Constants.AutoCapture.targetText] == nil,
              SwiftUITitleCapturePolicy.shouldRun(
                config: config, isSwiftUIHost: true
              ),
              !swiftUIRoot.up_flagInSubtree(containing: point, \.userpilotIgnoreInteractions) else { return }

        // A fast first tap after navigation can beat the debounced screen-appear
        // scan, and a scroll can reveal rows the cache hasn't seen: make sure the
        // cache covers this tap before resolving it.
        SwiftUIScanCache.shared.prepareForTapResolution(
            at: point, in: window, tappedView: self, logger: config.logger
        )
        guard let title = SwiftUITitleResolver.shared.resolveTitle(
            at: point, in: window, captureAccessibility: config.enableInteractionAccessibilityLabelCapture,
            logger: config.logger
        ) else { return }

        let isRedacted = swiftUIRoot.up_flagInSubtree(containing: point, \.userpilotRedactText)
        properties[Constants.AutoCapture.targetText] = isRedacted
            ? Constants.AutoCapture.reductText
            : resolvedInteractionText(title)
    }
}
