//
//  UIView+Extensions.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIView+Extensions provides helper methods and utilities for UIView
//  including distance calculations, corner radius, first responder finding,
//  and click tracking logic.
//

import UIKit

// MARK: - Global Functions

/// Calculates distance from view bottom edge to screen bottom
/// - Parameter view: The UIView to measure from
/// - Returns: Distance in points, or nil if view not in window
internal func distanceFromViewToScreenBottom(view: UIView) -> CGFloat? {
    guard let window = view.window else { return nil }
    let viewFrameInWindow = view.convert(view.bounds, to: window)
    let screenHeight = UIScreen.main.bounds.height
    let distance = screenHeight - viewFrameInWindow.maxY
    return distance
}

/// Calculates distance from view top edge to screen top
/// - Parameter view: The UIView to measure from
/// - Returns: Distance in points, or nil if view not in window
internal func distanceFromViewToScreenTop(view: UIView) -> CGFloat? {
    guard let window = view.window else { return nil }
    let viewFrameInWindow = view.convert(view.bounds, to: window)
    let distance = viewFrameInWindow.minY
    return distance
}

/// Extension providing corner radius utilities for UIView
internal extension UIView {
    /// Sets corner radius only on top corners of the view
    /// - Parameter radius: The corner radius to apply
    func setTopCornerRadius(_ radius: CGFloat) {
        self.clipsToBounds = true
        self.layer.cornerRadius = radius
        self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

}

// MARK: - First Responder Extension

/// Extension providing first responder finding functionality
internal extension UIView {
    /// Finds the first responder in the view hierarchy
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

    /// Determines if the app is using right-to-left layout
    var isAppRTL: Bool {
        UIView.userInterfaceLayoutDirection(for: self.semanticContentAttribute) == .rightToLeft
    }

}

// MARK: - Label Extraction Extension

/// Extension providing label extraction utilities for UIView
internal extension UIView {
    /// Extracts fallback label text from view or subviews
    /// - Returns: Extracted label text or nil
    func extractFallbackLabel() -> String? {
        if let label = self.subviews.first(where: { $0 is UILabel }) as? UILabel {
            return label.text
        }

        if let button = self as? UIButton {
            return button.currentTitle ?? button.accessibilityLabel
        }

        for subview in self.subviews {
            if let label = subview as? UILabel, let text = label.text {
                return text
            }
        }

        return nil
    }
}

// MARK: - Click Tracking Extension

/// Extension providing click tracking logic for UIView
internal extension UIView {
    /// Determines if a click on the view should be tracked
    /// - Returns: True if click should be tracked, false otherwise
    func shouldTrackClick() -> Bool {
        // 1. ✅ UIControl subclasses are ALWAYS tracked (UIButton, UISwitch, UISlider, etc.)
        if self is UIControl {
            return true
        }

        // 2. ✅ Views with .button accessibility trait
        //    This is what .userpilotRecognizeClickAnalytics() adds!
        if self.accessibilityTraits.contains(.button) {
            return true
        }

        // 3. ✅ Views explicitly marked with userpilotRecognizeClickAnalytics() (UIKit only)
        if self.userpilot_isExplicitlyRecognized {
            return true
        }

        // 4. ✅ Views with tap gesture recognizers
        //    Catches custom interactive views with gestures
        if let gestures = self.gestureRecognizers,
           gestures.contains(where: { $0 is UITapGestureRecognizer }) {
            return true
        }

        // 5. ✅ Views with .link trait (for navigation)
        if self.accessibilityTraits.contains(.link) {
            return true
        }

        // 6. ❌ Everything else is NOT tracked
        // This filters out: labels, images, scroll views, background views, etc.
        return false
    }
}

// MARK: - capture IBOutlet for UIview

internal extension UIView {
    /// Finds the closest UIViewController in the responder chain
    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }

    /// Resolves the IBOutlet property name by inspecting the owning view controller's ivars
    /// For example, if a VC has `@IBOutlet weak var searchTextField: UITextField!`,
    /// this returns "searchTextField" when called on that text field instance.
    func resolveReferenceName() -> String? {
        guard let viewController = findViewController() else { return nil }

        var vcClass: AnyClass? = type(of: viewController)

        // Walk up the class hierarchy to find the ivar
        while let currentClass = vcClass {
            var count: UInt32 = 0
            guard let ivars = class_copyIvarList(currentClass, &count) else {
                vcClass = class_getSuperclass(currentClass)
                continue
            }

            defer { free(ivars) }

            for index in 0..<Int(count) {
                let ivar = ivars[index]
                guard let namePtr = ivar_getName(ivar) else { continue }

                // Only read object-type ivars (type encoding starts with "@")
                // Reading primitive/struct ivars with object_getIvar causes EXC_BAD_ACCESS
                guard let typeEncoding = ivar_getTypeEncoding(ivar) else { continue }
                let encoding = String(cString: typeEncoding)
                guard encoding.hasPrefix("@") else { continue }

                let name = String(cString: namePtr)

                // Safe to read now — this ivar holds an object reference
                let value = object_getIvar(viewController, ivar)
                if let view = value as? UIView, view === self {
                    return name
                }
            }

            vcClass = class_getSuperclass(currentClass)

            // Stop at UIViewController level
            if vcClass == UIViewController.self {
                break
            }
        }

        return nil
    }
}
