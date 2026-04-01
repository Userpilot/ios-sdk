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
/// Redaction: the SDK uses UIView.getTextContent() and getAccessibilityLabelContent() (below)
/// which return "****" when shouldRedactText/shouldRedactAccessibilityLabel is true. Both
/// Config (disableInteractionTextCapture, disableInteractionAccessibilityLabelCapture) and
/// API properties (userpilotRedactText, userpilotRedactAccessibilityLabel on responder chain)
/// are checked and applied. resolve(view:) and resolveElementData(view:) implement the same
/// semantics and are available for a single unified path if needed.
internal enum UIKitViewResolver {
    // MARK: - Static Methods

    /// Resolves raw text content from UIKit views (no redaction).
    /// Prefer view.getTextContent() for capture so redaction is applied.
    static func resolve(view: UIView) -> String? {
        if let label = view as? UILabel {
            return label.text
        }

        if let button = view as? UIButton {
            return button.title(for: .normal)
                ?? button.currentTitle
                ?? button.titleLabel?.text
        }

        if let textField = view as? UITextField {
            return textField.text
        }

        if let textView = view as? UITextView {
            return textView.text
        }

        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            return accessibilityLabel
        }

        return nil
    }

    /// Extracts element tracking data with redaction (returns "****" when shouldRedact*).
    /// Currently unused; capture paths use view.getTextContent() / getAccessibilityLabelContent() instead.
    static func resolveElementData(view: UIView) -> ElementTrackingPayload {
        // Get text with redaction support
        let elementLabel: String?
        if view.shouldRedactText() {
            let rawLabel = resolveElementLabel(view: view)
            elementLabel = rawLabel != nil ? AutoCaptureConstants.reductText : nil
        } else {
            elementLabel = resolveElementLabel(view: view)
        }

        // Get accessibility ID with redaction support
        let accessibilityId: String?
        if view.shouldRedactAccessibilityLabel() {
            let rawId = resolveAccessibilityId(view: view)
            accessibilityId = rawId != nil ? AutoCaptureConstants.reductText : nil
        } else {
            accessibilityId = resolveAccessibilityId(view: view)
        }

        return ElementTrackingPayload(
            elementType: resolveElementType(view: view),
            elementLabel: elementLabel,
            accessibilityId: accessibilityId,
            screenHierarchyPath: resolveHierarchyPath(view: view),
            positionIndex: resolvePositionIndex(view: view)
        )
    }

    /// Resolves the hierarchical path of a view in the view tree.
    /// Each node is identified by: accessibilityIdentifier > accessibilityLabel > index in parent.
    /// The root segment is replaced with the resolved screen name (e.g. "HomeScreen").
    /// - Parameter view: The UIView to resolve path for
    /// - Returns: Hierarchical path string, example:
    /// "HomeScreen > UIView[index:0] > UIView[accessibilityLabel:0] > UIButton[id:login_button]"
    static func resolvePath(view: UIView) -> String {
        var path = [String]()
        var currentView: UIView? = view

        while let node = currentView {
            let parent = node.superview
            var desc = "\(type(of: node))"

            if let id = node.accessibilityIdentifier, !id.isEmpty {
                desc += "[id:\(id)]"
            } else if let label = node.accessibilityLabel, !label.isEmpty {
                desc += "[accessibilityLabel:\(label)]"
            } else if let parent = parent,
                      let index = parent.subviews.firstIndex(of: node) {
                desc += "[index:\(index)]"
            }

            path.append(desc) // ✅ changed here
            currentView = parent
        }

        // replace LAST element (root) with screen name
        if !path.isEmpty {
            path[path.count - 1] = view.userpilotResolvedScreenName()
        }

        return path.joined(separator: " > ")
    }
//    static func resolvePath(view: UIView) -> String {
//        var path = [String]()
//        var currentView: UIView? = view
//        while let node = currentView {
//            let parent = node.superview
//            var desc = "\(type(of: node))"
//            if let id = node.accessibilityIdentifier, !id.isEmpty {
//                desc += "[id:\(id)]"
//            } else if let label = node.accessibilityLabel, !label.isEmpty {
//                desc += "[accessibilityLabel:\(label)]"
//            } else if let parent = parent, let index = parent.subviews.firstIndex(of: node) {
//                desc += "[index:\(index)]"
//            }
//            path.insert(desc, at: 0)
//            currentView = parent
//        }
//        if !path.isEmpty {
//            path[0] = view.userpilotResolvedScreenName()
//        }
//        return path.joined(separator: " > ")
//    }

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

    /// Gets a unique tag or identifier for the element
    /// - Parameter view: The UIView to get tag for
    /// - Returns: Element tag string
    static func elementTag(view: UIView) -> String {
        if let tag = view.accessibilityIdentifier {
            return tag
        } else if view.tag != 0 {
            return "\(view.tag)"
        } else {
            return resolvePath(view: view)
        }
    }

    // MARK: - Element Type Resolution

    // Resolves the element type based on UIView class type
    // - Parameter view: The UIView to resolve type for
    // - Returns: Element type string
    // swiftlint:disable:next cyclomatic_complexity superfluous_disable_command
    private static func resolveElementType(view: UIView) -> String {
        return String(describing: type(of: view))
    }

    // MARK: - Element Label Resolution

    /// Resolves the element label or text content
    /// - Parameter view: The UIView to resolve label for
    /// - Returns: Element label string or nil
    private static func resolveElementLabel(view: UIView) -> String? {
        if let label = view as? UILabel {
            return label.text
        }

        if let button = view as? UIButton {
            return button.title(for: .normal)
                ?? button.currentTitle
                ?? button.titleLabel?.text
        }

        if let textField = view as? UITextField {
            return textField.placeholder ?? textField.text
        }

        if let textView = view as? UITextView {
            return textView.text
        }

        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            return accessibilityLabel
        }

        return nil
    }

    // MARK: - Accessibility ID Resolution

    /// Resolves the accessibility identifier of the view
    /// - Parameter view: The UIView to resolve accessibility ID for
    /// - Returns: Accessibility identifier string or nil
    private static func resolveAccessibilityId(view: UIView) -> String? {
        return view.accessibilityIdentifier
    }

    // MARK: - Hierarchy Path Resolution

    /// Resolves the hierarchical path of the view in the view tree.
    /// Each node is identified by: accessibilityIdentifier > accessibilityLabel > index in parent.
    /// The root segment is replaced with the resolved screen name.
    /// - Parameter view: The UIView to resolve hierarchy path for
    /// - Returns: Hierarchical path string, e.g. "HomeScreen > UIView[0] > UIButton[login_button]"
    private static func resolveHierarchyPath(view: UIView) -> String {
        return resolvePath(view: view)
    }

    // MARK: - Position Index Resolution

    /// Resolves the position index of the view within its parent
    /// - Parameter view: The UIView to resolve position for
    /// - Returns: Position index integer
    private static func resolvePositionIndex(view: UIView) -> Int {
        guard let superview = view.superview else { return 0 }
        return superview.subviews.firstIndex(of: view) ?? 0
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

    /// Checks if interactions should be ignored (API: userpilotIgnoreInteractions on responder chain).
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

    /// Checks if text should be redacted: Config (disableInteractionTextCapture)
    /// and API (userpilotRedactText on responder chain).
    /// - Returns: True if text should be redacted
    func shouldRedactText() -> Bool {
        if let config = Userpilot.isInitialized ? Userpilot.shared.config : nil,
           config.disableInteractionTextCapture {
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
    /// Config (disableInteractionAccessibilityLabelCapture) and API
    /// (userpilotRedactAccessibilityLabel on responder chain).
    /// - Returns: True if accessibility labels should be redacted
    func shouldRedactAccessibilityLabel() -> Bool {
        if let config = Userpilot.isInitialized ? Userpilot.shared.config : nil,
           config.disableInteractionAccessibilityLabelCapture {
            return true
        }
        var responder: UIResponder? = self
        while let current = responder {
            if current.userpilotRedactAccessibilityLabel { return true }
            responder = current.next
        }
        return false
    }

    /// Returns the text content of this view, redacted if necessary.
    /// Falls back to searching subviews for a UILabel when the view itself
    /// is a private/unknown type (e.g., _UIAlertControllerActionView).
    /// - Returns: The text content or redacted placeholder
    func getTextContent() -> String? {
        if shouldRedactText() {
            return AutoCaptureConstants.reductText
        }

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
        if shouldRedactAccessibilityLabel() {
            return AutoCaptureConstants.reductText
        }

        guard let label = accessibilityLabel, !label.isEmpty else {
            return nil
        }

        return label
    }
}
