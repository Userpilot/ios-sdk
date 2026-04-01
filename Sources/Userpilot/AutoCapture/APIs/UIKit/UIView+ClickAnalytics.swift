//
//  UIView+ClickAnalytics.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIView+ClickAnalytics provides extensions for enabling click analytics recognition
//  on UIKit views that may not be automatically detected as clickable.
//

import UIKit

// MARK: - Public API

/// Extension providing click analytics recognition functionality for UIKit views.
/// `open` allows subclasses to override if needed, consistent with `UIKit+Screen.swift`.
extension UIView {

    /// Manually enables analytics collection and tooltip guides display on this UIView.
    ///
    /// Use this API on rare occasions when the Userpilot SDK does not automatically
    /// recognize a clickable feature. This is particularly useful for:
    ///
    /// 1. **Custom interactive views** that don't inherit standard button behavior
    /// 2. **Views with tap gesture recognizers** added programmatically
    /// 3. **Container views** that act as buttons but aren't UIButton instances
    ///
    /// ## Requirements
    ///
    /// This API only works on UIViews that inherit from UIResponder (which is most UIViews).
    ///
    /// ## How it works
    ///
    /// This method:
    /// - Enables user interaction on the view
    /// - Adds a tap gesture recognizer if one doesn't exist
    /// - Sets accessibility traits to mark the view as a button
    /// - Makes the view recognizable by the Userpilot SDK's automatic tracking system
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // Example 1: Custom card view that should be tappable
    /// let cardView = UIView()
    /// cardView.backgroundColor = .systemBlue
    /// cardView.layer.cornerRadius = 8
    /// // Add your custom UI elements...
    /// cardView.userpilotRecognizeClickAnalytics()
    ///
    /// // Example 2: Container view acting as a button
    /// let customButton = UIView()
    /// let label = UILabel()
    /// label.text = "Custom Button"
    /// customButton.addSubview(label)
    /// customButton.userpilotRecognizeClickAnalytics()
    /// ```
    ///
    /// ## When NOT to use this API
    ///
    /// You do NOT need to use this API for:
    /// - Standard UIButton instances (automatically recognized)
    /// - UIControl subclasses (automatically recognized)
    /// - Views that already properly report touch events
    ///
    /// Enables click analytics recognition for UIKit views
    /// - Important: Call after view is configured and before adding to hierarchy
    @objc
    open func userpilotRecognizeClickAnalytics() {
        // 1. Enable user interaction (required for touch events)
        self.isUserInteractionEnabled = true

        // 2. Set accessibility traits to identify as a button
        // This helps the SDK's accessibility scanner recognize it as clickable
        self.accessibilityTraits.insert(.button)

        // 3. If no gesture recognizer exists, add a tap gesture recognizer
        // This ensures the view can receive and respond to taps
        let hasGestureRecognizer = self.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) ?? false

        if !hasGestureRecognizer {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userpilot_handleTap(_:)))
            tapGesture.cancelsTouchesInView = false // Don't interfere with other gestures
            self.addGestureRecognizer(tapGesture)
        }

        // 4. Mark the view as explicitly recognized for analytics
        // This internal flag helps the SDK identify views that should be tracked
        self.userpilot_isExplicitlyRecognized = true
    }

    /// Internal tap handler for recognized views
    /// - Parameter gesture: The tap gesture recognizer
    @objc private func userpilot_handleTap(_ gesture: UITapGestureRecognizer) {
        // The actual click tracking is handled by the UIWindow.swizzleSendEvent()
        // This gesture simply ensures the view is responsive to taps
        // The SDK's automatic tracking will capture the event
    }
}

// MARK: - Private

private var explicitlyRecognizedKey: UInt8 = 0

// MARK: - Internal

/// Extension providing explicit recognition flag for UIView
internal extension UIView {
    // Internal flag to mark views that were explicitly recognized via the API
    // swiftlint:disable:next identifier_name
    var userpilot_isExplicitlyRecognized: Bool {
        get {
            return objc_getAssociatedObject(self, &explicitlyRecognizedKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &explicitlyRecognizedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
