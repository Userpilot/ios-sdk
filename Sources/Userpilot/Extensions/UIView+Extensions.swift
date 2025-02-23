//
//  UIView+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `UIView+Extension` contains extensions with helper methods for the `UIView` class.
//

import UIKit

/// Calculates the distance from the bottom edge of a given view to the bottom of the screen.
/// - Parameter view: The `UIView` for which the distance is to be calculated.
/// - Returns: A `CGFloat` value representing the distance, or `nil` if the view is not part of a window.
internal func distanceFromViewToScreenBottom(view: UIView) -> CGFloat? {
    guard let window = view.window else { return nil }
    let viewFrameInWindow = view.convert(view.bounds, to: window)
    let screenHeight = UIScreen.main.bounds.height
    let distance = screenHeight - viewFrameInWindow.maxY
    return distance
}

/// Calculates the distance from the top edge of a given view to the top of the screen.
/// - Parameter view: The `UIView` for which the distance is to be calculated.
/// - Returns: A `CGFloat` value representing the distance, or `nil` if the view is not part of a window.
internal func distanceFromViewToScreenTop(view: UIView) -> CGFloat? {
    guard let window = view.window else { return nil }
    let viewFrameInWindow = view.convert(view.bounds, to: window)
    let distance = viewFrameInWindow.minY
    return distance
}

internal extension UIView {

    func setTopCornerRadius(_ radius: CGFloat) {
        self.clipsToBounds = true
        self.layer.cornerRadius = radius
        self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

}

/// Extension to Find First Responder
internal extension UIView {
    var firstResponder: UIResponder? {
        if self.isFirstResponder {
            return self
        }
        for subview in subviews {
            if let firstResponder = subview.firstResponder {
                return firstResponder
            }
        }
        return nil
    }
}
