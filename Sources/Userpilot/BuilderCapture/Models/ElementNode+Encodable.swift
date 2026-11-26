//
//  ElementNode+Encodable.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Encodes the capture tree without retaining native view references.
//

import UIKit

// MARK: - Encodable

extension ElementNode: Encodable {

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Node

    /// Encodes the subtree while omitting absent values and empty child arrays.
    ///
    /// Only targetable descendants are written: a child without a selector is
    /// replaced by its own targetable descendants. The node encoded first (the
    /// document root) is always written.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeID, forKey: .nodeID)
        var properties = encoder.container(keyedBy: ElementPropertyKeys.self)
        try properties.encode(nativeType, forKey: .targetClass)
        try properties.encodeIfPresent(displayName, forKey: .targetText)
        try container.encode(CaptureRect(bounds), forKey: .bounds)
        try container.encodeIfPresent(visibleBounds.map(CaptureRect.init), forKey: .visibleBounds)
        try container.encodeIfPresent(selector?.toMap(), forKey: .selector)
        let targetableChildren = children.flatMap(\.targetableNodes)
        if !targetableChildren.isEmpty {
            try container.encode(targetableChildren, forKey: .children)
        }
    }

    /// This node when it has a selector, otherwise its nearest descendants that do.
    private var targetableNodes: [ElementNode] {
        selector != nil ? [self] : children.flatMap(\.targetableNodes)
    }
}

// MARK: - Rect

/// Encodable form of `CGRect`, flattened to the four scalars the capture
/// contract uses (rather than Core Graphics' nested `origin` / `size`).
internal struct CaptureRect: Encodable {

    let posX: CGFloat
    let posY: CGFloat
    let width: CGFloat
    let height: CGFloat

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Rect

    init(_ rect: CGRect) {
        self.posX = rect.origin.x
        self.posY = rect.origin.y
        self.width = rect.width
        self.height = rect.height
    }
}
