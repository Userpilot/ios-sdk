//
//  UIKitAutoCaptureProperties.swift
//  Userpilot
//
//  Created by Motasem Hamed on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIKitAutoCaptureProperties provides properties for controlling automatic capture
//  behavior on UIKit views and view controllers, including ignoring interactions
//  and redacting text/accessibility labels.
//

import UIKit

// MARK: - Associated Object Keys

private var userpilotIgnoreInteractionsKey: UInt8 = 0
private var userpilotRedactTextKey: UInt8 = 0
private var userpilotRedactAccessibilityLabelKey: UInt8 = 0

// MARK: - UIResponder Extension

/// Public extension providing autocapture control properties for UIResponder.
/// These properties can be set on UIView, UIViewController, or other responders
/// to control how Userpilot captures interactions and text.
public extension UIResponder {

    // MARK: - Ignore Interactions

    /// Whether to ignore all interactions for this responder and its descendants.
    ///
    /// When set to `true`, Userpilot will not capture any interaction events
    /// (clicks, taps, etc.) for this view/view controller or any of its children.
    ///
    /// This property is recursive - if set on a parent view, all child views
    /// will also have their interactions ignored.
    ///
    /// Example (Interface Builder):
    /// Set "Userpilot Ignore Interactions" to "On" in the Attributes Inspector.
    ///
    /// Example (Code):
    /// ```swift
    /// pinContainerView.userpilotIgnoreInteractions = true
    /// ```
    @objc
    var userpilotIgnoreInteractions: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &userpilotIgnoreInteractionsKey) as? Bool {
                return value
            }
            return false
        }
        set {
            objc_setAssociatedObject(
                self,
                &userpilotIgnoreInteractionsKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Redact Text

    /// Whether to redact text content for this responder and its descendants.
    ///
    /// When set to `true`, any text captured from this view/view controller
    /// will be replaced with `****` in the event data.
    ///
    /// This is useful for views that may contain sensitive information like
    /// passwords, credit card numbers, or personal data.
    ///
    /// Example (Interface Builder):
    /// Set "Userpilot Redact Text" to "On" in the Attributes Inspector.
    ///
    /// Example (Code):
    /// ```swift
    /// passwordTextField.userpilotRedactText = true
    /// ```
    @objc
    var userpilotRedactText: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &userpilotRedactTextKey) as? Bool {
                return value
            }
            return false
        }
        set {
            objc_setAssociatedObject(
                self,
                &userpilotRedactTextKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Redact Accessibility Label

    /// Whether to redact accessibility labels for this responder and its descendants.
    ///
    /// When set to `true`, any accessibility labels captured from this view/view controller
    /// will be replaced with `****` in the event data.
    ///
    /// Because text can be copied to accessibility labels when accessibility services
    /// are enabled, you may want to set this alongside `userpilotRedactText`.
    ///
    /// Example (Interface Builder):
    /// Set "Userpilot Redact Accessibility Label" to "On" in the Attributes Inspector.
    ///
    /// Example (Code):
    /// ```swift
    /// sensitiveButton.userpilotRedactAccessibilityLabel = true
    /// ```
    @objc
    var userpilotRedactAccessibilityLabel: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &userpilotRedactAccessibilityLabelKey) as? Bool {
                return value
            }
            return false
        }
        set {
            objc_setAssociatedObject(
                self,
                &userpilotRedactAccessibilityLabelKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

// MARK: - UIView Extension

/// Internal extension providing helper methods for checking autocapture properties
internal extension UIView {

    /// Checks if interactions should be ignored for this view by traversing the responder chain
    /// - Returns: True if interactions should be ignored
    func shouldIgnoreInteractions() -> Bool {
        var responder: UIResponder? = self

        while let current = responder {
            if current.userpilotIgnoreInteractions {
                return true
            }
            responder = current.next
        }

        return false
    }

    /// Checks if text should be redacted for this view by traversing the responder chain
    /// - Returns: True if text should be redacted
    func shouldRedactText() -> Bool {
        // Check global config first
        if let config = Userpilot.isInitialized ? Userpilot.shared.config : nil {
            if config.disableInteractionTextCapture {
                return true
            }
        }

        var responder: UIResponder? = self

        while let current = responder {
            if current.userpilotRedactText {
                return true
            }
            responder = current.next
        }

        return false
    }

    /// Checks if accessibility labels should be redacted for this view by traversing the responder chain
    /// - Returns: True if accessibility labels should be redacted
    func shouldRedactAccessibilityLabel() -> Bool {
        // Check global config first
        if let config = Userpilot.isInitialized ? Userpilot.shared.config : nil {
            if config.disableInteractionAccessibilityLabelCapture {
                return true
            }
        }

        var responder: UIResponder? = self

        while let current = responder {
            if current.userpilotRedactAccessibilityLabel {
                return true
            }
            responder = current.next
        }

        return false
    }

    /// Returns the text content of this view, redacted if necessary.
    /// Falls back to searching subviews for a UILabel when the view itself
    /// is a private/unknown type (e.g., _UIAlertControllerActionView).
    /// - Returns: The text content or redacted placeholder
    func getTextContent() -> String? {
        var text: String?

        if let label = self as? UILabel {
            text = label.text
        } else if let button = self as? UIButton {
            text = button.title(for: .normal)
                ?? button.currentTitle
                ?? button.titleLabel?.text
        } else if let textField = self as? UITextField {
            text = textField.placeholder ?? textField.text
        } else if let textView = self as? UITextView {
            text = textView.text
        } else {
            // Fallback: search subviews for the first UILabel with text
            text = findLabelText(in: self)
        }

        guard let content = text, !content.isEmpty else {
            return nil
        }

        if shouldRedactText() {
            return "****"
        }

        return content
    }

    /// Recursively searches subviews for the first UILabel with non-empty text
    private func findLabelText(in view: UIView) -> String? {
        for subview in view.subviews {
            if let label = subview as? UILabel, let text = label.text, !text.isEmpty {
                return text
            }
            if let found = findLabelText(in: subview) {
                return found
            }
        }
        return nil
    }

    /// Returns the accessibility label of this view, redacted if necessary
    /// - Returns: The accessibility label or redacted placeholder
    func getAccessibilityLabelContent() -> String? {
        guard let label = accessibilityLabel, !label.isEmpty else {
            return nil
        }

        if shouldRedactAccessibilityLabel() {
            return "****"
        }

        return label
    }
}
