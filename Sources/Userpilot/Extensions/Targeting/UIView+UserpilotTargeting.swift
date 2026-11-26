//
//  UIView+UserpilotTargeting.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Reads a UIKit hierarchy and SwiftUI target marker views into snapshot nodes.
//  Main-thread-only traversal; selector scoring lives in `ElementTargeting`.
//

import UIKit

// MARK: - Traversal

internal extension UIView {

    /// Builds an `ElementNode` tree rooted at this view.
    ///
    /// Call on a window: the window's own bounds define the visible screen area
    /// and its safe-area insets seed the inset accumulation.
    ///
    /// Visits at most `ElementTreeLimits.maxVisitedNodes` views; past that the
    /// tree holds only what was walked.
    func userpilotElementNode() -> ElementNode? {
        var walk = UserpilotElementWalk()
        return userpilotElementNode(
            in: bounds,
            safeAreaInsets: safeAreaInsets,
            clippedTo: bounds,
            tabIndices: [:],
            walk: &walk
        )
    }

    /// Recursive step of the traversal.
    ///
    /// Subtrees outside the window bounds are pruned. Clipped containers still
    /// recurse because their children may remain visible.
    ///
    /// A view exposes identity only when its centre is inside the inherited safe
    /// area. Child insets accumulate with `max()` and apply only to descendants;
    /// applying them to this view would reject its own safe-area edge.
    ///
    /// Visible bounds also intersect every clipping ancestor. The centre test
    /// alone does not account for ancestor clipping, such as a scrolled row.
    ///
    /// - Parameters:
    ///   - bounds: the visible window rect, in window coordinates. Constant for
    ///     the whole walk.
    ///   - safeAreaInsets: insets accumulated from every ancestor so far.
    ///   - clipBounds: the visible region inherited from clipping ancestors.
    ///   - tabIndices: the `tab[N]` assignment for the enclosing `UITabBar`
    ///     subtree, keyed by view identity. Empty outside a tab bar, and
    ///     re-seeded by each `UITabBar` the walk enters (see
    ///     `userpilotTabIndices()`).
    ///   - walk: node ids and the visit budget for the whole walk.
    /// - Returns: the node, or `nil` when this view and its children are all
    ///   off-screen, or the visit budget is spent.
    private func userpilotElementNode(
        in bounds: CGRect,
        safeAreaInsets: UIEdgeInsets,
        clippedTo clipBounds: CGRect,
        tabIndices: [ObjectIdentifier: Int],
        walk: inout UserpilotElementWalk
    ) -> ElementNode? {
        guard let nodeID = walk.visit() else { return nil }

        // Cached once per node: `convert(_:to:)` walks up the hierarchy, so
        // re-reading it per use would make the traversal quadratic in depth.
        let absoluteBounds = convert(self.bounds, to: nil)

        // Prune subtrees whose full bounds do not intersect the window.
        guard absoluteBounds.intersects(bounds) else { return nil }

        let childInsets = UIEdgeInsets(
            top: max(safeAreaInsets.top, self.safeAreaInsets.top),
            left: max(safeAreaInsets.left, self.safeAreaInsets.left),
            bottom: max(safeAreaInsets.bottom, self.safeAreaInsets.bottom),
            right: max(safeAreaInsets.right, self.safeAreaInsets.right)
        )

        // Only clipping ancestors restrict their descendants' visible region.
        let childClipBounds = clipsToBounds
            ? clipBounds.intersection(absoluteBounds)
            : clipBounds

        // Tab identity is scoped to one tab bar's subtree, so a `UITabBar`
        // replaces whatever it inherited with its own assignment and every
        // descendant then simply looks itself up. The tab bar itself is never
        // tagged, which is why this applies to the *child* map only.
        let childTabIndices = self is UITabBar ? userpilotTabIndices() : tabIndices

        let children = userpilotChildNodes(
            in: bounds,
            safeAreaInsets: childInsets,
            clippedTo: childClipBounds,
            tabIndices: childTabIndices,
            walk: &walk
        )

        let safeBounds = bounds.inset(by: safeAreaInsets)
        let visibleRect = safeBounds
            .intersection(absoluteBounds)
            .intersection(clipBounds)

        // Identity requires the centre point to be inside the inherited safe area.
        let centrePoint = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        let autoTag = UIView.userpilotAutoTag(tabIndex: tabIndices[ObjectIdentifier(self)])
        let selector = safeBounds.contains(centrePoint)
            ? userpilotSelectorProperties(autoTag: autoTag)
            : nil

        let nativeType = "\(type(of: self))"

        return ElementNode(
            nodeID: nodeID,
            nativeType: nativeType,
            displayName: userpilotBuilderText,
            bounds: absoluteBounds,
            visibleBounds: visibleRect.isNull ? nil : visibleRect,
            selector: selector,
            children: children,
            view: self
        )
    }

    /// Whether this view or an ancestor is hidden, or their combined alpha is
    /// 0.01 or less. UIKit already ignores views below 0.01 for touches.
    var userpilotIsHiddenOrTransparent: Bool {
        var alpha: CGFloat = 1
        var current: UIView? = self
        while let view = current {
            if view.isHidden { return true }
            alpha *= view.alpha
            current = view.superview
        }
        return alpha <= 0.01
    }

    /// Reads displayed text on main, independently of analytics enablement, analytics redaction and
    /// selector identity: redaction applies to analytics only, never to Builder capture.
    /// Never substitutes identifiers, accessibility descriptions or editable input values.
    private var userpilotBuilderText: String? {
        guard self is UIButton || self is UILabel || self is UITextView else { return nil }
        var ancestor: UIView? = self
        while let current = ancestor {
            if current is UITextField { return nil }
            if let textView = current as? UITextView, textView.isEditable || textView.isSecureTextEntry {
                return nil
            }
            ancestor = current.superview
        }

        let text: String?
        switch self {
        case let button as UIButton:
            text = button.currentAttributedTitle?.string ?? button.currentTitle
        case let label as UILabel:
            text = label.attributedText?.string ?? label.text
        case let textView as UITextView:
            text = textView.attributedText?.string ?? textView.text
        default:
            text = nil
        }
        return text?.isEmpty == false ? text : nil
    }

    /// Walks the immediate subviews, pruning hidden subtrees.
    ///
    /// Hidden views are skipped **before** recursing, not filtered afterwards:
    /// a hidden container is usually the largest subtree in the app (an
    /// off-screen tab, a collapsed sheet), and descending into it is the main
    /// avoidable cost in the whole walk.
    ///
    /// `tabIndices` is handed straight through with no counter of its own: tab
    /// identity is decided once per `UITabBar` by position, not accumulated
    /// across a parent's subview list. That is what makes it survive UIKit
    /// burying the buttons several levels deeper than they used to be.
    private func userpilotChildNodes(
        in bounds: CGRect,
        safeAreaInsets: UIEdgeInsets,
        clippedTo clipBounds: CGRect,
        tabIndices: [ObjectIdentifier: Int],
        walk: inout UserpilotElementWalk
    ) -> [ElementNode] {
        subviews.compactMap { subview -> ElementNode? in
            guard !subview.isHidden else { return nil }

            return subview.userpilotElementNode(
                in: bounds,
                safeAreaInsets: safeAreaInsets,
                clippedTo: clipBounds,
                tabIndices: tabIndices,
                walk: &walk
            )
        }
    }

    /// Reads this view's identity properties.
    ///
    /// - Returns: the properties, or `nil` when the view exposes no identity at
    ///   all and therefore can never be targeted.
    private func userpilotSelectorProperties(autoTag: String?) -> SelectorProperties? {
        let properties = SelectorProperties(
            userpilotID: (self as? UserpilotTargetView)?.userpilotID,
            accessibilityIdentifier: accessibilityIdentifier,
            autoTag: autoTag,
            // UIKit's unset default is 0, so treat 0 as "no tag" rather than as
            // an identity every untagged view in the app would share.
            tag: tag != 0 ? "\(tag)" : nil,
            accessibilityLabel: accessibilityLabel
        )
        return properties.isEmpty ? nil : properties
    }

    /// Whether this view is one of UIKit's private tab-bar buttons.
    ///
    /// Private names vary (`UITabBarButton`, `_UITabButton`). Strip a leading
    /// underscore and require both the `UITab` prefix and `Button` suffix to
    /// exclude tab containers and selection views. An unrecognised rename simply
    /// receives no generated identity.
    private var userpilotIsTabBarButton: Bool {
        let name = "\(type(of: self))"
        let bare = name.hasPrefix("_") ? String(name.dropFirst()) : name
        return bare.hasPrefix("UITab") && bare.hasSuffix("Button")
    }

    /// Assigns one `tab[N]` per on-screen tab, for this tab bar's whole subtree.
    ///
    /// Call on a `UITabBar`. Three things force the shape of this:
    ///
    /// 1. **Scope is the subtree, not the subview list.** Modern UIKit nests the
    ///    buttons under `_UITabBarPlatterView` → `ContentView`, three levels
    ///    below the bar, so counting a parent's immediate subviews finds none.
    /// 2. **Numbering is by screen position, not traversal order.** Position is
    ///    the only thing that survives UIKit reorganising the tree, and it is
    ///    what `tab[N]` has always meant.
    /// 3. **Duplicates collapse.** A modern tab bar renders two complete sets of
    ///    buttons at identical frames (`SelectedContentView` and `ContentView`).
    ///    Tagging both would make every tab selector resolve `.ambiguous`, which
    ///    is worse than the silent miss it replaced — so buttons sharing a
    ///    horizontal position are one logical tab and get one tag.
    ///
    /// Run once per `UITabBar` and handed down the recursion, so the main walk
    /// stays single-pass and this stays linear in the bar's (tiny) subtree.
    ///
    /// - Returns: the index for each view that should carry a tag, keyed by
    ///   object identity. Exactly one view per index.
    private func userpilotTabIndices() -> [ObjectIdentifier: Int] {
        var representatives: [CGFloat: UIView] = [:]

        userpilotForEachTabButton { button in
            // Rounded to the nearest point rather than compared exactly:
            // duplicates come out of the same layout arithmetic, so this only has
            // to absorb coordinate-conversion noise, not merge genuinely distinct
            // tabs — real tabs sit ~86pt apart.
            let midX = button.convert(button.bounds, to: nil).midX.rounded()

            // First encountered wins. The walk is depth-first in UIKit subview
            // order, which is deterministic for a given layout, so the same view
            // is picked on every pass and the tag does not migrate between
            // captures. The duplicates share a frame, so the choice cannot move
            // the tooltip's anchor either way.
            if representatives[midX] == nil {
                representatives[midX] = button
            }
        }

        // `tab[N]` is a *positional*, left-to-right identity: index 0 is the
        // left-most tab on screen. An RTL layout therefore reverses which tab is
        // index 0. That is deliberate and not corrected here — the selector
        // contract defines `tab[N]` positionally, and the Builder authors against
        // the same screen the user sees.
        var indices: [ObjectIdentifier: Int] = [:]
        for (index, midX) in representatives.keys.sorted().enumerated() {
            guard let button = representatives[midX] else { continue }
            indices[ObjectIdentifier(button)] = index
        }
        return indices
    }

    /// Depth-first walk of this subtree, calling `body` for each tab button.
    ///
    /// Hidden subtrees are skipped for the reason the main traversal skips them,
    /// plus one specific to this walk: a hidden button never reaches the node
    /// tree, so letting it claim an index would delete that `tab[N]` from the
    /// capture entirely.
    private func userpilotForEachTabButton(_ body: (UIView) -> Void) {
        for subview in subviews where !subview.isHidden {
            if subview.userpilotIsTabBarButton {
                // A button's own children are labels and images, never buttons,
                // so there is nothing below it worth descending into.
                body(subview)
            } else {
                subview.userpilotForEachTabButton(body)
            }
        }
    }

    /// Builds an SDK-generated identity for a view the host app cannot tag.
    ///
    /// UIKit creates tab buttons privately, so `tab[N]` provides positional
    /// identity when the host cannot set an accessibility identifier or tag.
    private static func userpilotAutoTag(tabIndex: Int?) -> String? {
        tabIndex.map { "tab[\($0)]" }
    }
}

// MARK: - Walk State

/// Node ids and visit budget for one traversal. Ids are visit-order numbers, unique within
/// the walk only; WebView capture keys its replacements by them, and DOM nodes use UUIDs so
/// they never collide with a native id.
private struct UserpilotElementWalk {
    private var visitedCount = 0

    /// Counts one visit and returns its node id, or `nil` once the budget is spent.
    mutating func visit() -> String? {
        guard visitedCount < ElementTreeLimits.maxVisitedNodes else { return nil }
        defer { visitedCount += 1 }
        return String(visitedCount)
    }
}
