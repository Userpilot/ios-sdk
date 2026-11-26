//
//  CaptureAnnotation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Draws target outlines into a separate capture preview.
//

import UIKit

// MARK: - Targetable Rects

internal extension ElementNode {

    /// Every rect in this subtree that a selector could point at.
    ///
    /// Uses `targetRect` (visible area when clipped, full frame otherwise), the
    /// same rect target resolution hands to the tooltip layout — so a box drawn
    /// here is exactly where a tooltip would anchor.
    func targetableRects() -> [CGRect] {
        var rects: [CGRect] = []

        if selector != nil {
            rects.append(targetRect)
        }

        for child in children {
            rects.append(contentsOf: child.targetableRects())
        }

        return rects
    }
}

// MARK: - Annotation

internal extension UIImage {

    /// Returns a copy of this image with `rects` outlined and tinted.
    ///
    /// Rendered at this image's own scale so the annotated copy stays pixel-for-
    /// pixel comparable with the original that gets saved.
    ///
    /// - Parameter rects: rects in image points.
    /// - Returns: the annotated image, or `self` when there is nothing to draw.
    func annotated(with rects: [CGRect]) -> UIImage {
        guard !rects.isEmpty else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.preferredRange = .standard

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(at: .zero)
            context.cgContext.setFillColor(CaptureAnnotationStyle.fill.cgColor)
            context.cgContext.setStrokeColor(CaptureAnnotationStyle.stroke.cgColor)
            context.cgContext.setLineWidth(CaptureAnnotationStyle.lineWidth)
            context.cgContext.addRects(rects)
            context.cgContext.drawPath(using: .fillStroke)
        }
    }
}

// MARK: - Style

/// Colours for the annotation overlay.
///
/// A translucent fill plus a solid stroke, so overlapping boxes stay readable
/// and the underlying screenshot is still visible through them — nested views
/// (a button inside a cell inside a table) routinely produce three stacked
/// rects.
private enum CaptureAnnotationStyle {
    static let fill = CapturePillView.Palette.brand.withAlphaComponent(0.1)
    static let stroke = CapturePillView.Palette.brand
    static let lineWidth: CGFloat = 1
}
