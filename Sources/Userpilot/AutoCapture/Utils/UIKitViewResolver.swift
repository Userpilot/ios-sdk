//
//  UIKitViewResolver.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIKitViewResolver provides utilities for resolving element properties and generating
//  unique identifiers for UIKit view elements in automatic analytics capture.
//

import UIKit

/// `UIKitViewResolver` provides utilities for UIKit view element identification and tracking.
///
/// Text for published events uses ``UIView/getTextContent()`` and ``UIView/getAccessibilityLabelContent()``
/// (see extension below), which apply Config flags and `userpilotRedact*` on the responder chain.
internal enum UIKitViewResolver {

    /// Resolves the hierarchy path of a view from leaf to root, joined by `;`.
    ///
    /// Each segment follows the pattern:
    /// `SimpleName:attr__accessibility_label="...",attr__id="...",attr__index="..."`
    ///
    /// Attribute selection priority is:
    /// 1. `id`                  — accessibility identifier (highest fidelity)
    /// 2. `accessibility_label` — accessibility label
    /// 3. `index`               — position in parent (stable fallback)
    ///
    /// Note: Attributes are always emitted in alphabetical order:
    /// `attr__accessibility_label`, `attr__id`, `attr__index`.
    ///
    /// A `;SCREEN_NAME:…` segment from `screenNameTracker` is appended when publishing
    /// interaction events in `AutoCapturer`, not here.
    ///
    /// - Parameter view: The UIView to resolve the path for.
    /// - Returns: Hierarchical path string in leaf-to-root order.
    static func resolvePath(view: UIView) -> String {
        var path = [String]()
        var currentView: UIView? = view

        while let node = currentView {
            let parent = node.superview
            var desc = "\(type(of: node))"
            var attributes = ""

            // Match the Android accessibility model: `accessibility_label` (and `accessibility_id`)
            // are static developer-set identifiers, not PII text content, so they're governed only
            // by the accessibility-label flag — never by text redaction. This mirrors Android's
            // `shouldRedactContentDescription`, which intentionally does NOT call `shouldRedact()`.
            // We also keep the `value == "****"` short-circuit so any pre-redacted value that
            // somehow reaches us is still stripped. `attr__index` below is always emitted.
            let accessibilityRedacted = node.shouldRedactAccessibilityLabel()

            if let label = node.accessibilityLabel?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !label.isEmpty,
               label != AutoCaptureConstants.reductText,
               !accessibilityRedacted {
                attributes += "attr__accessibility_label=\"\(label.replacingOccurrences(of: "\"", with: "\\\""))\""
            }

            if let id = node.accessibilityIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !id.isEmpty,
               id != AutoCaptureConstants.reductText,
               !accessibilityRedacted {
                attributes += "attr__id=\"\(id.replacingOccurrences(of: "\"", with: "\\\""))\""
            }

            let indexInParent: Int
            if let parent = parent,
               let index = parent.subviews.firstIndex(of: node) {
                indexInParent = index
            } else {
                indexInParent = 0
            }

            attributes += "attr__index=\"\(indexInParent)\""

            if !attributes.isEmpty {
                desc += ":\(attributes)"
            }

            path.append(desc)
            currentView = parent
        }

        return path.joined(separator: ";")
    }

    /// Resolves the view and path to use for capture, respecting userpilotIgnoreInnerHierarchy.
    /// When a view or any ancestor has ignore inner hierarchy, that view is the "effective" view:
    /// path and element type come from it, and text is redacted as "****" when effective view ≠ touched view.
    /// - Parameter view: The view that was touched or sent the action
    /// - Returns: (effectiveView, path) for use in element_path and element_type/text
    static func resolvePathForCapture(view: UIView) -> (effectiveView: UIView, path: String) {
        let effectiveView = view.userpilotEffectiveViewForCapture()
        let path = resolvePath(view: effectiveView)
        return (effectiveView, path)
    }
}

// MARK: - Internal

/// Internal extension providing helper methods for checking autocapture properties
internal extension UIView {

    /// Returns the view to use for path/type when capturing: the first self or ancestor that has
    /// userpilotIgnoreInnerHierarchy == true. If none, returns self.
    func userpilotEffectiveViewForCapture() -> UIView {
        var current: UIView? = self
        while let view = current {
            if view.userpilotIgnoreInnerHierarchy {
                return view
            }
            current = view.superview
        }
        return self
    }

    /// Checks if interactions should be ignored.
    /// Honors both:
    /// - `userpilotIgnoreInteractions` on the responder chain
    /// - screen-level untracked flag (`ScreenNameTracker.untrackedScreenKey`) on any UIViewController
    /// - Returns: True if interactions should be ignored
    func shouldIgnoreInteractions() -> Bool {
        var responder: UIResponder? = self

        while let current = responder {
            if current.userpilotIgnoreInteractions {
                return true
            }
            if let viewController = current as? UIViewController {
                let isUntracked =
                    (objc_getAssociatedObject(
                        viewController,
                        &ScreenNameTracker.untrackedScreenKey
                    ) as? Bool) ?? false
                if isUntracked {
                    return true
                }
            }
            responder = current.next
        }

        return false
    }

    /// Checks if text should be redacted: Config (`enableInteractionTextCapture`)
    /// and API (userpilotRedactText on responder chain).
    /// - Returns: True if text should be redacted
    func shouldRedactText() -> Bool {
        if let config = Userpilot.isInitialized ? Userpilot.shared.config : nil, !config.enableInteractionTextCapture {
            return true
        }
        var responder: UIResponder? = self
        while let current = responder {
            if current.userpilotRedactText { return true }
            responder = current.next
        }
        return false
    }

    /// Checks if accessibility labels should be redacted:
    /// Config (`enableInteractionAccessibilityLabelCapture`) and API
    /// (userpilotRedactAccessibilityLabel on responder chain).
    /// - Returns: True if accessibility labels should be redacted
    func shouldRedactAccessibilityLabel() -> Bool {
        if let config = Userpilot.isInitialized ? Userpilot.shared.config : nil,
            !config.enableInteractionAccessibilityLabelCapture {
            return true
        }
        var responder: UIResponder? = self
        while let current = responder {
            if current.userpilotRedactAccessibilityLabel { return true }
            responder = current.next
        }
        return false
    }

    /// Direct text from `UILabel`, `UIButton`, `UITextField`, and `UITextView` only (no redaction, no subview crawl).
    /// - Parameters:
    ///   - textFieldPreferPlaceholder: When true, `UITextField` uses placeholder before `text` (capture UX).
    ///   - includeAccessibilityFallback: When true and no control text is found, uses non-empty `accessibilityLabel`.
    /// - Returns: First non-empty match, or nil
    fileprivate func userpilotRawDirectText(
        textFieldPreferPlaceholder: Bool,
        includeAccessibilityFallback: Bool
    ) -> String? {
        if let label = self as? UILabel {
            guard let text = label.text, !text.isEmpty else { return nil }
            return text
        }
        if let button = self as? UIButton {
            let text =
                button.title(for: .normal)
                ?? button.currentTitle
                ?? button.titleLabel?.text
            guard let text, !text.isEmpty else { return nil }
            return text
        }
        if let textField = self as? UITextField {
            let text = textFieldPreferPlaceholder
                ? (textField.placeholder ?? textField.text)
                : textField.text
            guard let text, !text.isEmpty else { return nil }
            return text
        }
        if let textView = self as? UITextView {
            guard let text = textView.text, !text.isEmpty else { return nil }
            return text
        }
        if includeAccessibilityFallback,
            let label = accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
            !label.isEmpty {
            return label
        }
        return nil
    }

    /// Returns the text content of this view, redacted if necessary.
    /// Falls back to searching subviews for a UILabel when the view itself
    /// is a private/unknown type (e.g., _UIAlertControllerActionView).
    /// - Returns: The text content or redacted placeholder
    func getTextContent() -> String? {
        if shouldRedactText() {
            return AutoCaptureConstants.reductText
        }

        if let direct = userpilotRawDirectText(
            textFieldPreferPlaceholder: true,
            includeAccessibilityFallback: false
        ) {
            return direct
        }

        if let nested = findLabelText(in: self) {
            return nested
        }

        return nil
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
        if shouldRedactAccessibilityLabel() {
            return AutoCaptureConstants.reductText
        }

        guard let label = accessibilityLabel, !label.isEmpty else {
            return nil
        }

        return label
    }
}
