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

// swiftlint:disable file_length

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
    /// ### Stability across navigation
    ///
    /// The walk terminates at the owning `UIViewController`'s root view and skips
    /// any UIKit private container classes encountered above it (`UITransitionView`,
    /// `UINavigationTransitionView`, `UILayoutContainerView`, `UIDropShadowView`,
    /// `UIViewControllerWrapperView`, `UIWindow`, plus anything whose class name
    /// starts with `_`). Those classes appear and disappear from `UIWindow.subviews`
    /// during transitions, modal presentations, and snapshot animations, so their
    /// `firstIndex(of:)` value is not stable across navigations and would cause the
    /// same UI element to produce different hierarchy strings on different visits.
    /// `indexInParent` is also computed against a filtered sibling list so that
    /// transient siblings (e.g. `_UIScrollViewScrollIndicator`) do not shift the
    /// position of stable siblings.
    ///
    /// - Parameters:
    ///   - view: The UIView to resolve the path for.
    ///   - leafIndexOverride: When non-nil, used as the leaf segment's `attr__index` in place of the
    ///     natural sibling index. Ancestor segments are unaffected. Used to disambiguate SwiftUI
    ///     sibling controls that otherwise collapse to identical paths (see ``siblingOrdinal(for:)``).
    /// - Returns: Hierarchical path string in leaf-to-root order.
    static func resolvePath(view: UIView, leafIndexOverride: Int? = nil) -> String {
        var path = [String]()
        var currentView: UIView? = view
        var isLeaf = true

        while let node = currentView {
            let parent = node.superview
            let className = String(describing: type(of: node))

            // The owning view controller's root view is the natural terminator
            // even when its class is on the deny-list — SwiftUI's
            // `UIHostingController.view` is `_UIHostingView`, which is private
            // and therefore in the skip set. Detecting the boundary here means
            // we always stop at the VC, regardless of whether we emit the node.
            let isOwningVCRootView =
                (node.next as? UIViewController)?.view === node

            // Skip UIKit private container classes for ancestors only. The leaf is
            // always emitted so the hierarchy describes the touched element even in
            // pathological cases where a private class somehow ends up at the leaf.
            if !isLeaf && shouldSkipInHierarchy(className) {
                if isOwningVCRootView {
                    break
                }
                currentView = parent
                continue
            }

            var desc = className
            var attributes = ""

            // `accessibility_label` (and `accessibility_id`) are static developer-set
            // identifiers, not PII text content, so they're governed only by the
            // accessibility-label flag — never by text redaction. We also keep the
            // `value == "****"` short-circuit so any pre-redacted value that somehow reaches
            // us is still stripped. `attr__index` below is always emitted.
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

            let indexValue = (isLeaf ? leafIndexOverride : nil) ?? stableIndex(of: node, in: parent)
            attributes += "attr__index=\"\(indexValue)\""

            if !attributes.isEmpty {
                desc += ":\(attributes)"
            }

            path.append(desc)
            isLeaf = false

            // Stop at the owning view controller's root view: above this, UIKit's
            // private window/transition chrome has unstable subview ordering across
            // navigations (the original `UITransitionView:attr__index` regression).
            if isOwningVCRootView {
                break
            }

            currentView = parent
        }

        return path.joined(separator: ";")
    }

    // MARK: - Stability helpers

    /// UIKit private container classes whose presence and ordering inside their
    /// parent's `subviews` is unstable across navigation transitions, modal
    /// presentations, snapshot animations, and split-view layout.
    ///
    /// Encoding any of these into the hierarchy string makes the resulting
    /// identity flicker between events fired on the same UI element. They are
    /// dropped from emitted segments and excluded from sibling-index calculations.
    private static let unstableContainerClassNames: Set<String> = [
        "UIWindow",
        "UITransitionView",
        "UIDropShadowView",
        "UILayoutContainerView",
        "UINavigationTransitionView",
        "UIViewControllerWrapperView"
    ]

    /// Returns `true` if `className` names a UIKit private container that should
    /// be excluded from emitted hierarchy segments and from sibling indexing.
    /// Anything starting with `_` is treated as Apple-private by convention.
    private static func shouldSkipInHierarchy(_ className: String) -> Bool {
        if className.hasPrefix("_") { return true }
        return unstableContainerClassNames.contains(className)
    }

    /// Position of `node` inside `parent`'s `subviews`, ignoring private siblings
    /// whose presence is transient (scroll indicators, snapshot/transition views).
    /// Falls back to the raw index when filtering can't locate the node.
    private static func stableIndex(of node: UIView, in parent: UIView?) -> Int {
        guard let parent = parent else { return 0 }
        let stableSiblings = parent.subviews.filter {
            !shouldSkipInHierarchy(String(describing: type(of: $0)))
        }
        if let index = stableSiblings.firstIndex(of: node) {
            return index
        }
        return parent.subviews.firstIndex(of: node) ?? 0
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

    // MARK: - SwiftUI sibling-control disambiguation

    /// Stable on-screen ordinal for a control among its same-kind siblings on the screen.
    ///
    /// SwiftUI sibling controls collapse to identical hierarchy strings: each `TextField`/`Slider`
    /// lives in its own private host chain, so each resolves to `attr__index="0"` and terminates at
    /// the same hosting controller. This computes a stable ordinal for `view` among all same-kind
    /// controls (`UITextField`, `UITextView`, or `UISlider`) under its owning view controller's root
    /// view, ordered by on-screen position (top→bottom, then left→right). Used as the leaf
    /// `attr__index`, so two controls become `…:attr__index="0"` and `…:attr__index="1"`. Unlike an
    /// `ObjectIdentifier`, this is derived from layout, so it is stable across app launches and
    /// identical for every user.
    ///
    /// - Returns: The control's ordinal, or `nil` when its kind isn't a known disambiguated control,
    ///   there are 0–1 matching siblings (single-control screens keep their natural index), or the
    ///   owning root can't be resolved.
    static func siblingOrdinal(for view: UIView) -> Int? {
        guard let root = owningViewControllerRootView(of: view) else { return nil }

        let isSameKind: (UIView) -> Bool
        if view is UITextField {
            isSameKind = { $0 is UITextField }
        } else if view is UITextView {
            isSameKind = { $0 is UITextView }
        } else if view is UISlider {
            isSameKind = { $0 is UISlider }
        } else {
            return nil
        }

        var matches: [UIView] = []
        collectViews(in: root, matching: isSameKind, into: &matches)
        guard matches.count > 1 else { return nil }

        let window = view.window
        func windowOrigin(_ candidate: UIView) -> CGPoint {
            (candidate.superview?.convert(candidate.frame, to: window) ?? candidate.frame).origin
        }

        let sorted = matches.sorted { lhs, rhs in
            let lhsOrigin = windowOrigin(lhs)
            let rhsOrigin = windowOrigin(rhs)
            if abs(lhsOrigin.y - rhsOrigin.y) > 0.5 { return lhsOrigin.y < rhsOrigin.y }
            return lhsOrigin.x < rhsOrigin.x
        }
        return sorted.firstIndex { $0 === view }
    }

    /// Walks up from `view` to the root view of the view controller that owns it — the same
    /// terminator `resolvePath` uses: a node whose `next` responder is a `UIViewController`
    /// whose `view` is that node.
    private static func owningViewControllerRootView(of view: UIView) -> UIView? {
        var node: UIView? = view
        while let current = node {
            if (current.next as? UIViewController)?.view === current {
                return current
            }
            node = current.superview
        }
        return nil
    }

    /// Depth-first collects every descendant of `root` (and `root`'s subtree) satisfying `matches`.
    private static func collectViews(
        in root: UIView,
        matching matches: (UIView) -> Bool,
        into result: inout [UIView]
    ) {
        for subview in root.subviews {
            if matches(subview) {
                result.append(subview)
            }
            collectViews(in: subview, matching: matches, into: &result)
        }
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
    /// - otherwise → `raw`
    func resolvedInteractionText(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if isInteractionTextCaptureDisabled() { return nil }
        if hasUserpilotRedactTextOptIn() { return AutoCaptureConstants.reductText }
        return raw
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
    /// - Returns: The text content, redaction placeholder, or `nil` when omitted
    func getTextContent() -> String? {
        if isInteractionTextCaptureDisabled() {
            return nil
        }
        if hasUserpilotRedactTextOptIn() {
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

    /// Returns the accessibility label of this view, applying accessibility-capture policy.
    /// - Returns: The label, redaction placeholder for opt-in, or `nil` when omitted
    func getAccessibilityLabelContent() -> String? {
        if isInteractionAccessibilityLabelCaptureDisabled() {
            return nil
        }
        if hasUserpilotRedactAccessibilityLabelOptIn() {
            return AutoCaptureConstants.reductText
        }

        guard let label = accessibilityLabel, !label.isEmpty else {
            return nil
        }

        return label
    }
}

// swiftlint:enable file_length
