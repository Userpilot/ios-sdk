//
//  ElementNode.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Snapshot nodes used by target resolution and Builder capture.
//  Full bounds and clipped visible bounds remain separate so consumers can
//  distinguish the view's extent from its visible anchor area.
//

import UIKit

// MARK: - Element Node

/// A native or logical element in a captured tree.
///
/// Captured on the main thread. Stored geometry describes that capture only.
@objc(UserpilotElementNode) public final class ElementNode: NSObject {

    /// Unique identity for this node **within this capture only**.
    ///
    /// Not stable across captures: the native walk numbers nodes in visit order,
    /// so another capture can reuse an id for a different view. It carries no
    /// host-app content, so it is safe to log and safe to send.
    @objc public let nodeID: String

    /// The view's class name (e.g. `UIButton`).
    @objc public let nativeType: String

    /// Displayed component text, encoded as `target_text` in Builder captures.
    /// The public property name is retained for wrapper compatibility. `nil` when unavailable.
    @objc public let displayName: String?

    /// Full frame in the window's base coordinate space, **unclipped** —
    /// `view.convert(view.bounds, to: nil)`.
    ///
    /// Measured in points, matching the admitted window's logical-scale screenshot.
    @objc public let bounds: CGRect

    /// The part of `bounds` inside the safe area and clipping ancestors, or `nil`
    /// when their intersection is empty.
    ///
    /// Distinct from `bounds` so a half-scrolled-off target is describable: the
    /// tooltip anchors to what the user can see, while `bounds` still records
    /// the view's real extent.
    public let visibleBounds: CGRect?

    /// Identity properties this view exposes, or `nil` when it has none *or* is
    /// not visible enough to be targeted.
    ///
    /// Both cases collapse to `nil` deliberately: a node
    /// without a selector cannot be matched, so an off-screen view is simply
    /// unmatchable rather than needing a separate visibility rejection later.
    /// The node itself is still emitted, because its children may be visible
    /// even when it is not.
    @objc public let selector: UserpilotElementSelector?

    /// Child views, front-most last (UIKit subview order). Hidden subtrees are
    /// pruned during traversal and never appear here.
    @objc public let children: [ElementNode]

    /// The live view this node was built from.
    ///
    /// Weak because the host owns its lifetime. Resolution reads fresh geometry
    /// rather than trusting a cached view that may now represent a reused cell.
    @objc public private(set) weak var view: UIView?

    /// Hosting surface for logical wrapper nodes; never used as their geometric anchor.
    private weak var ownershipSource: UIView?

    /// Native source used only to validate the nearest instance binding.
    @objc public var ownershipView: UIView? { ownershipSource ?? view }

    /// Drawn fully transparent although its host is visible, such as a web element with
    /// `opacity: 0`. Set only by the SDK's web capture; a native view is read live instead.
    /// Never serialized.
    var isTransparent = false

    /// Native and Swift wrapper construction. Bounds are in the admitted window's points.
    public init(
        nodeID: String, nativeType: String, displayName: String?, bounds: CGRect,
        visibleBounds: CGRect?, selector: UserpilotElementSelector?, children: [ElementNode],
        view: UIView?, ownershipView: UIView? = nil
    ) {
        self.nodeID = nodeID
        self.nativeType = nativeType
        self.displayName = displayName
        self.bounds = bounds
        self.visibleBounds = visibleBounds
        self.selector = selector
        self.children = children
        self.view = view
        self.ownershipSource = ownershipView
        super.init()
    }

    /// Objective-C wrapper construction for a logical element within its native hosting surface.
    @objc public convenience init(
        nodeID: String, nativeType: String, displayName: String?, bounds: CGRect,
        visibleBounds: CGRect, selector: UserpilotElementSelector?, children: [ElementNode], ownershipView: UIView
    ) {
        self.init(nodeID: nodeID, nativeType: nativeType, displayName: displayName, bounds: bounds,
                  visibleBounds: visibleBounds, selector: selector, children: children, view: nil,
                  ownershipView: ownershipView)
    }

    /// The rect a tooltip should anchor to: the visible part when there is one,
    /// otherwise the full frame.
    ///
    /// The full frame fallback avoids anchoring at the origin when clipping
    /// leaves no visible rectangle.
    var targetRect: CGRect {
        visibleBounds ?? bounds
    }
}

// MARK: - Matching

extension ElementNode {

    /// Collects every node in this subtree that scores above zero against
    /// `properties`.
    ///
    /// Returns all partial matches so the resolver can apply the score floor
    /// and detect ties at the highest score.
    ///
    /// - Parameter properties: the target-side identity to score against.
    /// - Returns: every scoring node, in traversal order.
    func matches(for properties: UserpilotElementSelector) -> [ElementMatch] {
        var results: [ElementMatch] = []

        if let selector {
            let score = selector.evaluateMatch(properties)
            if score > 0 {
                results.append(ElementMatch(node: self, score: score))
            }
        }

        for child in children {
            results.append(contentsOf: child.matches(for: properties))
        }

        return results
    }

    /// Total node count in this subtree, including self. Used for traversal-cost
    /// logging — the walk is main-thread work, so tree size is the number to
    /// watch. For the capture UI's "targetable elements" figure use
    /// `targetableCount`, which counts only nodes a tooltip could actually
    /// point at.
    var nodeCount: Int {
        children.reduce(1) { $0 + $1.nodeCount }
    }

    /// Number of nodes in this subtree that expose a selector, and so could be
    /// targeted by a published tooltip.
    ///
    /// The capture confirmation sheet warns when this is zero, because a capture
    /// with no targetable elements is authored against nothing.
    var targetableCount: Int {
        let own = selector == nil ? 0 : 1
        return children.reduce(own) { $0 + $1.targetableCount }
    }
}
