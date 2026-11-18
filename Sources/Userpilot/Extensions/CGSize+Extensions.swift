//
//  CGSize+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Scales a size to a new width or height at its own aspect.
//

import CoreGraphics

internal extension CGSize {
    /// This size at `newWidth`, keeping its aspect.
    func scaled(toWidth newWidth: CGFloat) -> CGSize {
        CGSize(width: newWidth, height: newWidth * height / width)
    }

    /// This size at `newHeight`, keeping its aspect.
    func scaled(toHeight newHeight: CGFloat) -> CGSize {
        CGSize(width: newHeight * width / height, height: newHeight)
    }
}
