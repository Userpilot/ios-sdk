//
//  UIView+UserpilotLabel.swift
//  Userpilot
//
//  Created by Motasem Hamed
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIView+UserpilotLabel stores SwiftUI-provided autocapture metadata on UIKit views using
//  associated objects, and exposes resolution helpers used by window and control capture paths.
//

import UIKit

// MARK: - Associated object keys

/// Keys for Objective-C associated objects on `UIView` instances.
enum AssociatedKeys {
    static var userpilotLabel: UInt8 = 0
    static var userpilotLabelViewType: UInt8 = 0
    static var userpilotForwardingDelegate: UInt8 = 0
}

// MARK: - Capture result

/// Resolved SwiftUI-driven label metadata for a window-space autocapture lookup.
struct UserpilotLabelCaptureResult {
    let label: String
    let viewType: String?
    let labeledView: UIView
}

// MARK: - UIView (autocapture metadata)

extension UIView {

    /// Developer-defined text from the SwiftUI `userpilotLabel(_:)` modifier for autocapture `element_text`.
    ///
    /// When set from the SwiftUI bridge, this value is preferred over inferred control text
    /// where the capture pipeline supports it.
    var userpilotLabel: String? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.userpilotLabel) as? String }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.userpilotLabel,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Short logical type name (e.g. `"Button"`) for autocapture `element_type` when present.
    var userpilotLabelViewType: String? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.userpilotLabelViewType) as? String }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.userpilotLabelViewType,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Returns the first non-empty `userpilotLabel` on `self` or any ancestor.
    ///
    /// Used by ``UIControl`` and other paths where the touched view is already the labeled host
    /// or sits under it in the responder chain.
    func resolveUserpilotLabel() -> String? {
        var current: UIView? = self
        while let view = current {
            if let label = view.userpilotLabel, !label.isEmpty {
                return label
            }
            current = view.superview
        }
        return nil
    }

    /// Returns the first non-empty `userpilotLabelViewType` on `self` or any ancestor.
    func resolveUserpilotLabelViewType() -> String? {
        var current: UIView? = self
        while let view = current {
            if let viewType = view.userpilotLabelViewType, !viewType.isEmpty {
                return viewType
            }
            current = view.superview
        }
        return nil
    }

    /// Resolves label metadata for a **window-space** touch, including a fallback search downward.
    ///
    /// Resolution order:
    ///
    /// 1. Walk from `self` toward the root and return the first view with a non-empty
    ///    `userpilotLabel` (same as `resolveUserpilotLabel()` but also returns the host view
    ///    and `userpilotLabelViewType`).
    /// 2. If none, perform a bounded depth-first search under `self`’s subviews for the
    ///    **deepest** view whose bounds contain `point` (in `window` coordinates) and that has
    ///    a non-empty `userpilotLabel`.
    ///
    /// Step 2 exists because SwiftUI hit-testing can report an ancestor (e.g. a platform
    /// container) while the SwiftUI modifier stored the label on a descendant control.
    ///
    /// - Parameters:
    ///   - point: Touch location in `window` coordinate space.
    ///   - window: The key window used to convert `point` into each candidate view’s bounds.
    /// - Returns: Label string, optional semantic type, and the concrete view that owns the label
    ///   (use the latter for `shouldRedactText()` when emitting `element_text`).
    func resolveUserpilotLabelCapture(
        atWindowPoint point: CGPoint,
        in window: UIWindow
    ) -> UserpilotLabelCaptureResult? {
        if let host = firstViewOnAncestorChainWithUserpilotLabel(),
           let label = host.userpilotLabel, !label.isEmpty {
            let viewType = host.userpilotLabelViewType
            let resolvedType = (viewType?.isEmpty == false) ? viewType : nil
            return UserpilotLabelCaptureResult(label: label, viewType: resolvedType, labeledView: host)
        }
        guard let host = labeledDescendantContainingPoint(point, in: window),
              let label = host.userpilotLabel, !label.isEmpty else { return nil }
        let viewType = host.userpilotLabelViewType
        let resolvedType = (viewType?.isEmpty == false) ? viewType : nil
        return UserpilotLabelCaptureResult(label: label, viewType: resolvedType, labeledView: host)
    }

    // MARK: - Private

    private func firstViewOnAncestorChainWithUserpilotLabel() -> UIView? {
        var current: UIView? = self
        while let view = current {
            if let label = view.userpilotLabel, !label.isEmpty {
                return view
            }
            current = view.superview
        }
        return nil
    }

    /// Deepest descendant (under `self`) that contains `point` and has a non-empty `userpilotLabel`.
    private func labeledDescendantContainingPoint(_ point: CGPoint, in window: UIWindow) -> UIView? {
        var best: UIView?
        var bestDepth = -1
        var visits = 0
        let maxVisits = 800

        func visit(_ view: UIView, depth: Int) {
            guard visits < maxVisits else { return }
            visits += 1
            let local = view.convert(point, from: window)
            guard view.bounds.contains(local) else { return }

            if let lab = view.userpilotLabel, !lab.isEmpty, depth > bestDepth {
                bestDepth = depth
                best = view
            }
            for child in view.subviews.reversed() {
                visit(child, depth: depth + 1)
            }
        }

        for child in subviews.reversed() {
            visit(child, depth: 1)
        }
        return best
    }
}
