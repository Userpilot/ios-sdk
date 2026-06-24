//
//  SwiftUITitleResolver.swift
//  Userpilot
//
//  Resolves the title of a tapped SwiftUI control — and ONLY the title. The
//  SDK's existing pipeline owns interception, eventing, hierarchy, redaction,
//  ignore-interactions, screen tracking and payload; this type is consulted by
//  `handleRegularViewTap` only when every existing extraction produced no text,
//  and it returns a plain `String?` that fills `target_text`.
//
//  PUBLIC API ONLY: accessibility reads go through `UserpilotSafeAccessibility`
//  (exception-guarded wrappers over the public UIAccessibility API), KVC probes
//  through `UserpilotSafeKVC` (public getter names only), and everything else is Swift
//  `Mirror` reflection. No private selectors, no NSInvocation, no dlopen/dlsym.
//
//  Resolution order (Stages 0–1 — `.userpilotLabel` and UIKit text extraction —
//  run in the SDK BEFORE this resolver):
//    Stage A — public accessibility-tree walk on the hosting ancestors.
//              Exact when the OS materialised the tree; empty otherwise. Gated
//              by `enableInteractionAccessibilityLabelCapture` and skipped on
//              `userpilotSkipAccessibilityScan` screens.
//    Stage B — display-list text map, optionally cross-checked with interactive
//              reflection inventory. Exact when paint-order layer pairing holds.
//              When no tappable/control-like title matches, resolution returns nil.
//

// swiftlint:disable file_length identifier_name opening_brace type_body_length
// swiftlint:disable:previous blanket_disable_command

import UIKit

#if canImport(UserpilotObjC)
    import UserpilotObjC
#endif

internal final class SwiftUITitleResolver {

    static let shared = SwiftUITitleResolver()
    private init() {}

    /// The single entry point. Returns the resolved SwiftUI control title, or
    /// nil when the tap resolves to no titled interactive element. The caller
    /// applies the SDK's redaction gate to the returned string.
    func resolveTitle(at pointInWindow: CGPoint, in window: UIWindow) -> String? {
        let hit = window.hitTest(pointInWindow, with: nil)
        #if DEBUG
            SwiftUIScanLog.log(
                "resolveTitle at \(pointInWindow) hit=\(hit.map { String(describing: type(of: $0)) } ?? "nil")"
            )
        #endif

        // Stage A — public accessibility-tree walk (config- and policy-gated).
        if accessibilityReadEnabled, let hit, !skipsAccessibility(hit: hit),
            let title = accessibilityTreeTitle(at: pointInWindow, hit: hit, in: window)
        {
            #if DEBUG
                SwiftUIScanLog.log("  ✓ STAGE A (accessibility): \"\(title)\"")
            #endif
            return title
        }

        // Stage B — display-list text map ∩ interactive inventory.
        let (textMap, interactive) = SwiftUIScanCache.shared.textResolution()
        if !textMap.isEmpty,
            let title = textMapTitle(
                at: pointInWindow, in: window,
                textMap: textMap, interactive: interactive)
        {
            #if DEBUG
                SwiftUIScanLog.log("  ✓ STAGE B (display-list): \"\(title)\"")
            #endif
            return title
        }

        #if DEBUG
            SwiftUIScanLog.log("  ✗ SwiftUI title resolution: nil")
        #endif
        return nil
    }

    // MARK: - Gating

    private var accessibilityReadEnabled: Bool {
        guard Userpilot.isInitialized, let userpilot = Userpilot.shared else { return false }
        return userpilot.config.enableInteractionAccessibilityLabelCapture
    }

    private func skipsAccessibility(hit: UIView) -> Bool {
        let (_, inventoryHost) = SwiftUIScanCache.shared.inventory()
        let resolvedHost = inventoryHost ?? hit.up_nearestViewController
        return resolvedHost.map { SwiftUIScanPolicy.shouldSkipAccessibility($0) } ?? false
    }

    // MARK: - Stage A: public accessibility-tree walk

    /// Per-host budget for the public accessibility walk — the tap path must
    /// never become the thing that janks the UI.
    private struct A11yWalkBudget {
        var visited = 0
        let maxVisited = 400
        let maxDepth = 8
        let maxChildrenPerNode = 100
        let deadline = Date().addingTimeInterval(0.015)  // 15 ms hard cap
        var isExhausted: Bool { visited >= maxVisited || Date() > deadline }
    }

    /// Traverse the PUBLIC accessibility element tree of the hosting ancestors
    /// and return the title of the smallest button-like element whose
    /// `accessibilityFrame` contains the tapped point. Innermost host wins.
    private func accessibilityTreeTitle(at pointInWindow: CGPoint, hit: UIView, in window: UIWindow)
        -> String?
    {
        let pointInScreen = window.convert(pointInWindow, to: nil)
        let hostingAncestors = hostingAncestors(from: hit)
        guard !hostingAncestors.isEmpty else { return nil }

        for host in hostingAncestors {
            var budget = A11yWalkBudget()
            var best: NSObject?
            var bestArea = CGFloat.greatestFiniteMagnitude

            walkAccessibilityTree(of: host, depth: 0, budget: &budget) { element in
                let frame = UserpilotSafeAccessibility.accessibilityFrame(of: element)
                guard !frame.isNull, frame.width > 0, frame.height > 0,
                    frame.contains(pointInScreen),
                    Self.isButtonLike(element)
                else { return }
                let area = frame.width * frame.height
                if area < bestArea {
                    best = element
                    bestArea = area
                }
            }

            if let best, let title = Self.anyTitle(on: best) {
                return title
            }
        }
        return nil
    }

    /// Depth-first traversal of the public accessibility element tree. Every
    /// read is exception-guarded (UserpilotSafeAccessibility) and bounded by `budget`.
    private func walkAccessibilityTree(
        of object: NSObject,
        depth: Int,
        budget: inout A11yWalkBudget,
        onElement: (NSObject) -> Void
    ) {
        if budget.isExhausted || depth > budget.maxDepth { return }
        budget.visited += 1

        if UserpilotSafeAccessibility.isAccessibilityElement(on: object) {
            onElement(object)
        }

        if let elements = UserpilotSafeAccessibility.accessibilityElements(of: object)
            as? [NSObject],
            !elements.isEmpty
        {
            for child in elements.prefix(budget.maxChildrenPerNode) {
                walkAccessibilityTree(
                    of: child, depth: depth + 1, budget: &budget, onElement: onElement)
                if budget.isExhausted { return }
            }
            return
        }

        let count = UserpilotSafeAccessibility.elementCount(on: object)
        // SwiftUI hosting views report NSNotFound when no tree exists.
        guard count > 0, count != NSNotFound else { return }
        for index in 0..<min(count, budget.maxChildrenPerNode) {
            guard let child = UserpilotSafeAccessibility.element(at: index, on: object) as? NSObject
            else { continue }
            walkAccessibilityTree(
                of: child, depth: depth + 1, budget: &budget, onElement: onElement)
            if budget.isExhausted { return }
        }
    }

    /// Button-likeness for accessibility hit objects: trait-based, plus the
    /// `.userpilotLabel` carrier view (which marks a custom tappable component).
    private static func isButtonLike(_ obj: NSObject) -> Bool {
        if UserpilotSafeAccessibility.accessibilityTraits(of: obj).up_containsButtonLike {
            return true
        }
        return String(describing: type(of: obj)).contains("LabelCarrierView")
    }

    // MARK: - Stage B: display-list text map

    /// Resolves a tap against the display-list text map: map the window point
    /// into content space through the text's painted layer (public
    /// `CALayer.convert`, live — scroll-proof), test it against each entry's hit
    /// frame, and require the title to match an interactive inventory record.
    /// Smallest hit frame wins. Returns the resolved (rendered) title.
    private func textMapTitle(
        at pointInWindow: CGPoint,
        in window: UIWindow,
        textMap: [DisplayListTextMap.Entry],
        interactive: [(title: String, viewType: String)]
    ) -> String? {
        // NOTE: do NOT bail when `interactive` is empty. The reflection inventory
        // is empty on a SwiftUI `NavigationStack` root (its body re-evaluates to
        // an empty navigation state, so no interactive records are produced), yet
        // the display-list text map still carries the on-screen button titles.
        // The styled-control fallback below resolves those geometrically
        // (text painted inside a background/control) without needing the
        // inventory — that is exactly the case it exists for.

        // Primary: the smallest containing text whose title the reflection
        // inventory confirms is an interactive control.
        var bestTitle: String?
        var bestArea = CGFloat.greatestFiniteMagnitude

        // Fallback: the smallest containing text that PAINTS as a styled control
        // (background larger than the glyph box). Used when the reflection
        // inventory can't enumerate the on-screen controls — notably a screen
        // pushed via `.navigationDestination`, whose content is closure-stored
        // and unreachable from the NavigationStack root's `rootView`. The
        // display-list geometry is authoritative; the inventory is best-effort.
        var fallbackTitle: String?
        var fallbackArea = CGFloat.greatestFiniteMagnitude
        #if DEBUG
        var hitCandidates: [String] = []
        #endif

        for entry in textMap {
            guard let title = entry.title,
                  entry.containsWindowPoint(pointInWindow, in: window) else { continue }
            #if DEBUG
            hitCandidates.append("\(title) styled=\(entry.isStyledControlTitleCandidate)")
            #endif

            let area = entry.hitFrame.width * entry.hitFrame.height
            if Self.interactiveRecord(matching: title, in: interactive) != nil {
                if area < bestArea {
                    bestTitle = title
                    bestArea = area
                }
            } else if entry.isStyledControlTitleCandidate {
                if area < fallbackArea {
                    fallbackTitle = title
                    fallbackArea = area
                }
            }
        }
        #if DEBUG
        if bestTitle == nil, fallbackTitle == nil, !hitCandidates.isEmpty {
            SwiftUIScanLog.log("    STAGE B candidates under tap but not resolvable: \(hitCandidates)")
        }
        #endif
        return bestTitle ?? fallbackTitle
    }

    // MARK: - Interactive-title matching

    /// Matches a RESOLVED rendered string against interactive inventory titles.
    /// Inventory titles may be unresolved format patterns (LocalizedStringKey
    /// storage — "Tapped %lld times"), so exact equality is tried first, then
    /// format-pattern matching.
    private static func interactiveRecord(
        matching resolved: String,
        in records: [(title: String, viewType: String)]
    ) -> (title: String, viewType: String)? {
        for record in records where record.title == resolved { return record }
        for record in records where record.title.contains("%") {
            if matchesFormatPattern(resolved, pattern: record.title) { return record }
        }
        return nil
    }

    /// True when `resolved` plausibly came from `pattern` by substituting its
    /// `%`-tokens: the literal chunks around the tokens must all appear, in
    /// order. Internal (not private) so it can be unit-tested via `@testable`.
    internal static func matchesFormatPattern(_ resolved: String, pattern: String) -> Bool {
        var chunks: [String] = []
        var current = ""
        var index = pattern.startIndex
        let tokenCharacters = Set("0123456789.@lduf$hzs")
        while index < pattern.endIndex {
            let ch = pattern[index]
            if ch == "%" {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                index = pattern.index(after: index)
                while index < pattern.endIndex, tokenCharacters.contains(pattern[index]) {
                    index = pattern.index(after: index)
                }
                continue
            }
            current.append(ch)
            index = pattern.index(after: index)
        }
        if !current.isEmpty { chunks.append(current) }
        guard !chunks.isEmpty else { return false }

        var remainder = resolved[resolved.startIndex...]
        for chunk in chunks {
            guard let range = remainder.range(of: chunk) else { return false }
            remainder = remainder[range.upperBound...]
        }
        return true
    }

    // MARK: - Title helpers

    private static func bestTitle(for view: UIView) -> String? {
        if let label = view as? UILabel, let t = trimmedNonEmpty(label.text) {
            return t
        }
        if let button = view as? UIButton,
            let t = trimmedNonEmpty(button.currentTitle ?? button.titleLabel?.text)
        {
            return t
        }
        if let tf = view as? UITextField,
            let t = trimmedNonEmpty(tf.placeholder ?? tf.text)
        {
            return t
        }
        if let tv = view as? UITextView, let t = trimmedNonEmpty(tv.text) {
            return t
        }
        return trimmedNonEmpty(view.accessibilityLabel)
    }

    /// Tries every reasonable title source for an arbitrary accessibility
    /// object — UIKit controls AND SwiftUI's internal text-bearing views. All
    /// reads are exception-guarded (UserpilotSafeAccessibility / UserpilotSafeKVC) or pure
    /// Swift `Mirror` reflection — public API only.
    private static func anyTitle(on obj: NSObject) -> String? {
        if let view = obj as? UIView, let t = bestTitle(for: view) {
            return t
        }
        if let t = trimmedNonEmpty(UserpilotSafeAccessibility.accessibilityLabel(of: obj)) {
            return t
        }
        if let t = trimmedNonEmpty(UserpilotSafeAccessibility.accessibilityValue(of: obj)) {
            return t
        }

        // SwiftUI bridge: `.userpilotLabel("Foo")` injects a hidden carrier view
        // that stores the user-provided text in a Swift `private var label`,
        // which is not @objc → not KVC-accessible. Read it via `Mirror`.
        let className = String(describing: type(of: obj))
        if className.contains("LabelCarrierView") {
            if let t = mirrorString(on: obj, named: "label") {
                return t
            }
        }

        // Defensive KVC probe via UserpilotSafeKVC (respondsToSelector + @try/@catch),
        // public getter names only.
        let keys = ["text", "title", "string", "currentTitle", "stringValue", "attributedText"]
        for key in keys {
            guard let raw = UserpilotSafeKVC.value(forKey: key, on: obj) else { continue }
            if let s = raw as? String, let trimmed = trimmedNonEmpty(s) {
                return trimmed
            }
            if let attr = raw as? NSAttributedString,
                let trimmed = trimmedNonEmpty(attr.string)
            {
                return trimmed
            }
        }
        return nil
    }

    /// Reads a Swift stored `String?` property from a class instance using
    /// `Mirror`. Walks the superclass chain too.
    private static func mirrorString(on obj: Any, named property: String) -> String? {
        var mirror: Mirror? = Mirror(reflecting: obj)
        while let m = mirror {
            for child in m.children where child.label == property {
                if let s = child.value as? String, let t = trimmedNonEmpty(s) {
                    return t
                }
            }
            mirror = m.superclassMirror
        }
        return nil
    }

    private static func trimmedNonEmpty(_ raw: String?) -> String? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        return s
    }

    // MARK: - Hosting ancestors

    /// Every hosting-view ancestor between `view` and the window root, ordered
    /// innermost-first then outermost last. SwiftUI's a11y tree usually lives on
    /// the outermost `_UIHostingView`.
    private func hostingAncestors(from view: UIView) -> [UIView] {
        var inner: [UIView] = []
        var outer: UIView?
        var current: UIView? = view
        while let v = current {
            if SwiftUIDetection.isHostingAccessibilityAncestor(v) {
                inner.append(v)
                outer = v
            }
            current = v.superview
        }
        if let outer, inner.last !== outer {
            inner.append(outer)
        }
        return inner
    }
}

// MARK: - Responder helper

extension UIResponder {
    /// Nearest enclosing `UIViewController` in the responder chain.
    var up_nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController { return vc }
            responder = current.next
        }
        return nil
    }
}

// MARK: - Trait helper

extension UIAccessibilityTraits {
    /// Traits that mark an element as a clickable "button" for autocapture
    /// purposes. Capture is button-first: static text, headers, fields and
    /// containers never produce a resolver-supplied title.
    fileprivate var up_containsButtonLike: Bool {
        if contains(.button) || contains(.link) { return true }
        if #available(iOS 17.0, *), contains(.toggleButton) { return true }
        return false
    }
}
