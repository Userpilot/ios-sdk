//
//  CaptureViewport.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines logical screenshot geometry and safe-area insets.
//

import UIKit

// MARK: - Viewport

/// How screenshot coordinates relate to element-tree coordinates.
internal struct CaptureViewport: Encodable {

    /// Always `screenshot_logical`: the element tree's rects are in the same
    /// space as the screenshot's pixels.
    let coordinateSpace: String

    /// Always `points`.
    let unit: String

    /// Screenshot pixels per point. `1` because the screenshot is rendered at
    /// logical scale — see `ScreenSnapshotter`.
    let pixelRatio: CGFloat

    let width: CGFloat
    let height: CGFloat

    /// Safe-area insets of the captured window. The traversal uses these to
    /// decide which elements were visible enough to be targetable, so the
    /// Builder needs them to explain why an element has no selector.
    let safeAreaInsets: CaptureEdgeInsets

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Viewport

    init(size: CGSize, pixelRatio: CGFloat, safeAreaInsets: UIEdgeInsets) {
        self.coordinateSpace = CaptureDocument.coordinateSpace
        self.unit = CaptureDocument.coordinateUnit
        self.pixelRatio = pixelRatio
        self.width = size.width
        self.height = size.height
        self.safeAreaInsets = CaptureEdgeInsets(safeAreaInsets)
    }
}

// MARK: - Insets

/// Encodable form of `UIEdgeInsets`.
internal struct CaptureEdgeInsets: Encodable {

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Insets

    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    init(_ insets: UIEdgeInsets) {
        self.top = insets.top
        self.left = insets.left
        self.bottom = insets.bottom
        self.right = insets.right
    }
}
