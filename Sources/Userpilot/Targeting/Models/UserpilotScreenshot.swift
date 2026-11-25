//
//  UserpilotScreenshot.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Carries a wrapper screenshot and the logical viewport described by its element tree.
//

import UIKit

/// A screenshot whose origin matches the captured element tree. Size and insets are in points.
/// The image may use any pixel density; Builder normalizes it to one pixel per point.
@objc public final class UserpilotScreenshot: NSObject {
    /// Pixels supplied by the native renderer or wrapper.
    @objc public let image: UIImage
    /// Logical viewport size represented by the image and element tree.
    @objc public let size: CGSize
    /// Content insets within this image; use zero for a system bar excluded from it.
    @objc public let insets: UIEdgeInsets

    /// All logical dimensions use points, independently of the image pixel density.
    @objc public init(image: UIImage, size: CGSize, insets: UIEdgeInsets) {
        self.image = image
        self.size = size
        self.insets = insets
        super.init()
    }

    /// Reject invalid geometry before allocating an image or publishing misleading coordinates.
    internal var isValid: Bool {
        let edges = [insets.top, insets.left, insets.bottom, insets.right]
        return size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0 &&
            image.size.width > 0 && image.size.height > 0 &&
            edges.allSatisfy { $0.isFinite && $0 >= 0 } &&
            insets.left + insets.right <= size.width && insets.top + insets.bottom <= size.height
    }
}
