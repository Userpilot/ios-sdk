//
//  UIView+CaptureResolution.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves native capture text and privacy from the view and its owning instance.
//

import UIKit

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

    /// Checks if text should be hidden for this view: Config (`enableInteractionTextCapture`)
    /// is off, or `userpilotRedactText` is set on the responder chain.
    ///
    /// Prefer ``resolvedInteractionText(_:)`` / ``getTextContent()`` when publishing `target_text`:
    /// those **omit** the field when capture is disabled and only emit the redaction placeholder
    /// for the per-view redact opt-in.
    /// - Returns: True if text should be hidden
    func shouldRedactText() -> Bool {
        isInteractionTextCaptureDisabled() || hasUserpilotRedactTextOptIn()
    }

    /// True when the owning instance has `enableInteractionTextCapture` set to `false`.
    func isInteractionTextCaptureDisabled() -> Bool {
        // Resolve the OWNING Userpilot instance from this view so the redaction
        // policy follows that tenant's config, not the host's. Critical for
        // multi-instance integrations: the host might allow text capture while
        // the embedded SDK requires redaction (or vice versa).
        if let config = InstanceResolver.shared.target(forSource: self)?.config {
            return !config.enableInteractionTextCapture
        }
        return false
    }

    /// True when `userpilotRedactText` is set on this responder or an ancestor.
    func hasUserpilotRedactTextOptIn() -> Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if current.userpilotRedactText { return true }
            responder = current.next
        }
        return false
    }

    /// Applies text-capture policy to a raw string for autocapture payloads.
    /// - Global text capture off → `nil` (omit `target_text`)
    /// - `userpilotRedactText` on the responder chain → redaction placeholder
    /// - otherwise → `raw`, collapsed to one line and bounded (see ``String/userpilotBoundedText()``)
    func resolvedInteractionText(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if isInteractionTextCaptureDisabled() { return nil }
        if hasUserpilotRedactTextOptIn() { return Constants.AutoCapture.reductText }
        return raw.userpilotBoundedText()
    }

    /// Text published when capture resolves to an ignore-inner-hierarchy ancestor.
    ///
    /// When text capture is enabled, the leaf text is masked with the redaction placeholder so
    /// inner content stays hidden. When text capture is disabled, returns `nil` so `target_text`
    /// is omitted — same omit policy as ``resolvedInteractionText(_:)`` / ``getTextContent()``.
    func ignoreInnerHierarchyTextPlaceholder() -> String? {
        if isInteractionTextCaptureDisabled() { return nil }
        return Constants.AutoCapture.reductText
    }

    /// Checks if accessibility labels should be hidden: Config
    /// (`enableInteractionAccessibilityLabelCapture`) is off, or
    /// `userpilotRedactAccessibilityLabel` is set on the responder chain.
    ///
    /// Prefer ``getAccessibilityLabelContent()`` when publishing `accessibility_label`: that
    /// **omits** the field when capture is disabled and only emits the redaction placeholder for
    /// the per-view redact opt-in.
    /// - Returns: True if accessibility labels should be hidden
    func shouldRedactAccessibilityLabel() -> Bool {
        isInteractionAccessibilityLabelCaptureDisabled() || hasUserpilotRedactAccessibilityLabelOptIn()
    }

    /// True when the owning instance has `enableInteractionAccessibilityLabelCapture` set to `false`.
    func isInteractionAccessibilityLabelCaptureDisabled() -> Bool {
        if let config = InstanceResolver.shared.target(forSource: self)?.config {
            return !config.enableInteractionAccessibilityLabelCapture
        }
        return false
    }

    /// True when `userpilotRedactAccessibilityLabel` is set on this responder or an ancestor.
    func hasUserpilotRedactAccessibilityLabelOptIn() -> Bool {
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

    /// Returns the text content of this view, applying text-capture policy.
    /// Falls back to searching subviews for a UILabel when the view itself
    /// is a private/unknown type (e.g., _UIAlertControllerActionView).
    /// - Parameter windowPoint: When set, the subview search only enters subviews containing
    ///   this point (window coordinates). Used inside SwiftUI hosting views, whose container
    ///   views hold unrelated UIKit controls (e.g. a Picker's segments) as subviews.
    /// - Returns: The text content, redaction placeholder, or `nil` when omitted
    func getTextContent(containing windowPoint: CGPoint? = nil) -> String? {
        if isInteractionTextCaptureDisabled() {
            return nil
        }
        if hasUserpilotRedactTextOptIn() {
            return Constants.AutoCapture.reductText
        }

        if let direct = userpilotRawDirectText(
            textFieldPreferPlaceholder: true,
            includeAccessibilityFallback: false
        ) {
            return direct.userpilotBoundedText()
        }

        if let nested = findLabelText(in: self, containing: windowPoint) {
            return nested.userpilotBoundedText()
        }

        return nil
    }

    /// Recursively searches subviews for the first UILabel with non-empty text.
    /// Hidden and `userpilotRedactText` subtrees are skipped so their content is never published.
    private func findLabelText(in view: UIView, containing windowPoint: CGPoint?) -> String? {
        for subview in view.subviews where subview.isUserpilotTextReadable {
            if let windowPoint, !subview.bounds.contains(subview.convert(windowPoint, from: nil)) {
                continue
            }
            if let label = subview as? UILabel, let text = label.text, !text.isEmpty {
                return text
            }
            if let found = findLabelText(in: subview, containing: windowPoint) {
                return found
            }
        }
        return nil
    }

    /// First non-empty text rendered anywhere inside this view's subtree, in front-to-back
    /// subview order, ignoring text-capture policy (callers apply it via
    /// ``resolvedInteractionText(_:)``).
    ///
    /// Used for row-level capture (`table_view_cell_selected` / `collection_view_item_selected`),
    /// where the interacted element is the whole row rather than the touched leaf. Hidden and
    /// `userpilotRedactText` subtrees are skipped.
    func userpilotFirstTextInSubtree() -> String? {
        for subview in subviews where subview.isUserpilotTextReadable {
            if let text = subview.userpilotRawDirectText(
                textFieldPreferPlaceholder: true,
                includeAccessibilityFallback: false
            ) {
                return text
            }
            if let nested = subview.userpilotFirstTextInSubtree() {
                return nested
            }
        }
        return nil
    }

    /// `false` for views whose text must never be harvested by a subtree crawl: invisible views
    /// and views the host opted out of with `userpilotRedactText`.
    private var isUserpilotTextReadable: Bool {
        guard !isHidden, alpha > 0.01 else { return false }
        return !userpilotRedactText
    }

    /// Returns the accessibility label of this view, applying accessibility-capture policy.
    /// - Returns: The label, redaction placeholder for opt-in, or `nil` when omitted
    func getAccessibilityLabelContent() -> String? {
        if isInteractionAccessibilityLabelCaptureDisabled() {
            return nil
        }
        if hasUserpilotRedactAccessibilityLabelOptIn() {
            return Constants.AutoCapture.reductText
        }

        guard let label = accessibilityLabel, !label.isEmpty else {
            return nil
        }

        return label
    }
}

internal extension UIView {
    /// Shares list identity/label finalization; the fallback stays lazy so each cell reads text
    /// only after the same label and ignored-inner-hierarchy checks as before.
    func completeListInteractionPayload(
        _ payload: inout InteractionPayload,
        touchedView: UIView?,
        resolveCellText: () -> String?
    ) {
        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.hierarchy = path
        if let userpilotLabel = (touchedView ?? self).resolveUserpilotLabel() {
            if let labelViewType = (touchedView ?? self).resolveUserpilotLabelViewType() {
                payload.targetClass = labelViewType
            }
            payload.elementText = (touchedView ?? self).resolvedInteractionText(userpilotLabel)
        } else if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
            payload.elementText = effectiveView.ignoreInnerHierarchyTextPlaceholder()
        } else {
            payload.elementText = resolveCellText()
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = touchedView?.getAccessibilityLabelContent()
        }
    }
}

internal extension UIView {
    /// Reads action metadata after the sender-specific capture gates, preserving privacy read order.
    func buildActionInteractionPayload(action: Selector, target: Any?) -> InteractionPayload {
        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        let useRedactedInner = (effectiveView !== self)

        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: String(describing: type(of: effectiveView))
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        payload.hierarchy = path

        if useRedactedInner {
            payload.elementText = ignoreInnerHierarchyTextPlaceholder()
        } else {
            payload.elementText = getTextContent()
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = getAccessibilityLabelContent()
            payload.targetViewName = resolveReferenceName()
        }

        return payload
    }
}

internal extension UIView {
    /// Builds regular-window-tap properties after touch routing has excluded controls and list rows.
    /// - Parameter limitsTextToTapPoint: Only a label under the tap may supply `target_text` (SwiftUI
    ///   button autocapture: a SwiftUI container's UIKit subviews can be unrelated controls).
    func buildWindowInteractionProperties(
        at point: CGPoint,
        in window: UIWindow,
        limitsTextToTapPoint: Bool = false
    ) -> [String: Any] {
        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        let useRedactedInner = (effectiveView !== self)

        var eventProperties: [String: Any] = [
            Constants.AutoCapture.targetClass: String(describing: type(of: effectiveView)),
            Constants.AutoCapture.hierarchy: path
        ]

        if let capture = resolveUserpilotLabelCapture(atWindowPoint: point, in: window) {
            if let labelViewType = capture.viewType {
                eventProperties[Constants.AutoCapture.targetClass] = labelViewType
            }
            if let resolvedLabel = capture.labeledView.resolvedInteractionText(capture.label) {
                eventProperties[Constants.AutoCapture.targetText] = resolvedLabel
            }
        } else if useRedactedInner {
            if let placeholder = ignoreInnerHierarchyTextPlaceholder() {
                eventProperties[Constants.AutoCapture.targetText] = placeholder
            }
        } else {
            if let accessibilityIdentifier = accessibilityIdentifier, !accessibilityIdentifier.isEmpty {
                eventProperties[Constants.AutoCapture.accessibilityIdentifier] = accessibilityIdentifier
            }
            if let accessibilityLabel = getAccessibilityLabelContent() {
                eventProperties[Constants.AutoCapture.accessibilityLabel] = accessibilityLabel
            }
            if let text = sectionContainerText() ?? getTextContent(containing: limitsTextToTapPoint ? point : nil) {
                eventProperties[Constants.AutoCapture.targetText] = text
            }
        }

        return eventProperties
    }

    /// Text for a tap that landed inside a table section header/footer or a collection
    /// supplementary view.
    ///
    /// These are single logical elements like rows are, so the container's own text is published
    /// rather than whichever leaf the finger hit — the same rule
    /// ``UITableViewCell/userpilotResolvedCellText(touchedView:)`` applies to cells. Returns `nil`
    /// for taps outside such a container, leaving the regular leaf resolution in place.
    private func sectionContainerText() -> String? {
        if let headerFooter = findParentTableViewHeaderFooter() {
            return headerFooter.userpilotResolvedHeaderFooterText(touchedView: self)
        }
        if let reusable = findParentCollectionReusableView() {
            return reusable.userpilotResolvedSupplementaryText(touchedView: self)
        }
        return nil
    }

}
