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

// MARK: - Private

private var userpilotIgnoreInteractionsKey: UInt8 = 0
private var userpilotRedactTextKey: UInt8 = 0
private var userpilotRedactAccessibilityLabelKey: UInt8 = 0
private var userpilotIgnoreInnerHierarchyKey: UInt8 = 0

// MARK: - Public API

/// Extension providing autocapture control properties for UIResponder.
/// Developers can override these on subclasses (e.g. custom `UIView`) to customize defaults,
/// matching `UIViewController` screen hooks in `UIKit+Screen.swift`.
extension UIResponder {

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
    open var userpilotIgnoreInteractions: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &userpilotIgnoreInteractionsKey) as? Bool {
                return value
            }
            return AutocaptureViewConfiguration.ignoreInteractionsDefault(for: type(of: self))
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

    // MARK: - Ignore Inner Hierarchy

    /// When `true`, touches inside this view are attributed to this view (path and type from this view,
    /// not from the specific child). Inner structure is hidden and element text is redacted as "****".
    /// Set on a container to suppress sensitive inner hierarchy (e.g. PIN pad).
    @objc
    open var userpilotIgnoreInnerHierarchy: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &userpilotIgnoreInnerHierarchyKey) as? Bool {
                return value
            }
            return AutocaptureViewConfiguration.ignoreInnerHierarchyDefault(for: type(of: self))
        }
        set {
            objc_setAssociatedObject(
                self,
                &userpilotIgnoreInnerHierarchyKey,
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
    open var userpilotRedactText: Bool {
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
    open var userpilotRedactAccessibilityLabel: Bool {
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
