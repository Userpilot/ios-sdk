//
//  SwiftUIReflection.swift
//  Userpilot
//
//  SwiftUI view-graph reflection (body-evaluating) — the default SwiftUI title
//  source. On modern iOS the accessibility tree of a hosting view is not
//  materialised for non-assistive clients, so the public UIKit-side a11y
//  traversal usually returns nothing; reflection fills the gap.
//
//  PUBLIC API ONLY: the root view is read through the public
//  `UIHostingController.rootView` property (via a type-erasing protocol
//  conformance), and the walk uses Swift `Mirror` plus the public `View.body`
//  requirement. No private selectors, no KVC into private storage.
//
//  A naive `Mirror` of the root view does NOT work: a SwiftUI view's content
//  is produced by its `body` — a computed property `Mirror` cannot see. So we
//  recursively evaluate `body`:
//    • COMPOSITE view (Body != Never): call `body`, recurse into the result.
//    • PRIMITIVE view (Body == Never: Text, Image, VStack, Button, …): never
//      call `body` (it traps on `Never`); Mirror-recurse the stored children
//
// swiftlint:disable:next line_length
// swiftlint:disable cyclomatic_complexity file_length function_body_length function_parameter_count identifier_name type_body_length
// swiftlint:disable:previous blanket_disable_command
//      instead — which is where a Button's `label` (the Text storing the
//      string) actually lives.
//  The `Body == Never` gate is what keeps us off the `fatalError` primitives
//  raise from `.body`.
//
//  TRAP GUARD: evaluating `body` re-runs view construction outside SwiftUI's
//  update graph, where graph-injected property wrappers are absent — accessing
//  one is a Swift trap (fatalError), not catchable. We never evaluate the body
//  of a view whose stored properties include a known graph-dependent wrapper
//  (`graphDependentWrapperTypes`, currently `@EnvironmentObject`); the walk
//  degrades to Mirror-recursing its stored children instead.
//
//  WARNING-POLICY GUARD: common state wrappers (`@State`, `@Binding`, etc.) do
//  not belong in the fatal-trap set because skipping them loses automatic
//  titles. Callers can still ask the walk to avoid evaluating those bodies when
//  a live render-tree source already exists, while allowing them as a last
//  resort on OS versions where live sources are empty.
//
//  NOTE (vs. the sample original): the SwiftUI-side ignore/redact policy
//  detection was intentionally NOT ported. Redaction and ignore-interactions
//  are owned by the SDK's existing responder-chain gates plus the hook-level
//  point-scoped downward flag check — see SWIFTUI_AUTOCAPTURE_MERGE_PLAN.md.
//

import UIKit
import SwiftUI

// MARK: - Public rootView access

/// Type-erasing hook into the PUBLIC `UIHostingController.rootView` property.
/// Conforming the generic class via an extension lets us read `rootView` from
/// any `UIHostingController<Content>` held as a plain `UIViewController` —
/// including SwiftUI's internal hosting subclasses (navigation stacks, tabs,
/// sheets), which all inherit it.
private protocol SwiftUIHostingRootProviding {
    var up_publicRootView: Any { get }
}

extension UIHostingController: SwiftUIHostingRootProviding {
    var up_publicRootView: Any { rootView }
}

internal enum SwiftUIReflection {

    // MARK: - Public

    struct ViewRecord: CustomStringConvertible {
        let title: String
        let viewType: String   // "Button" | "NavigationLink" | "Text" | "UserpilotLabel" | <type>
        let depth: Int
        let order: Int         // pre-order traversal index

        /// View types that represent a tappable control. Stage B intersects
        /// display-list text against the titles of these records.
        static let interactiveTypes: Set<String> = [
            "Button", "NavigationLink", "Toggle", "Menu", "Link", "UserpilotLabel"
        ]

        var isInteractive: Bool { Self.interactiveTypes.contains(viewType) }

        var description: String {
            "[\(order) d=\(depth)] \(viewType): \"\(title)\""
        }
    }

    enum BodyEvaluationPolicy: Equatable {
        case normal
        case avoidWarningProneState
        case allowWarningProneAsLastResort
    }

    /// Find the deepest visible `UIHostingController` reachable from this
    /// window. Kept for callers that want a single best guess.
    static func topmostHostingController(in window: UIWindow) -> UIViewController? {
        return allHostingControllers(in: window).last
    }

    /// EVERY hosting controller reachable from the window, ordered shallow →
    /// deep. SwiftUI `NavigationStack` / `TabView` push their content into
    /// CHILD hosting controllers, so the screen the user sees is usually the
    /// deepest one — not the root navigation shell. We reflect them all and
    /// merge.
    static func allHostingControllers(in window: UIWindow) -> [UIViewController] {
        guard let root = window.rootViewController else { return [] }
        var result: [UIViewController] = []
        var seen = Set<ObjectIdentifier>()

        func visit(_ vc: UIViewController, depth: Int) {
            if depth > 40 { return }
            let oid = ObjectIdentifier(vc)
            if seen.contains(oid) { return }
            seen.insert(oid)

            if isHostingController(vc) { result.append(vc) }

            for child in vc.children { visit(child, depth: depth + 1) }
            if let presented = vc.presentedViewController { visit(presented, depth: depth + 1) }
            if let nav = vc as? UINavigationController {
                for v in nav.viewControllers { visit(v, depth: depth + 1) }
            }
            if let tab = vc as? UITabBarController {
                for v in tab.viewControllers ?? [] { visit(v, depth: depth + 1) }
            }
        }

        visit(root, depth: 0)
        return result
    }

    /// Build the SwiftUI inventory for one hosting controller.
    ///
    /// - Parameter deadline: optional wall-clock cap. When nil (default) the
    ///   walk is bounded only by node/depth (today's behavior); callers on the
    ///   scan path pass a per-host deadline so one heavy host cannot monopolize
    ///   the main thread.
    static func extractInventory(
        from hostingController: UIViewController,
        deadline: Date? = nil,
        bodyEvaluationPolicy: BodyEvaluationPolicy = .normal
    ) -> [ViewRecord] {
        guard let rootView = rootView(of: hostingController) else {
            return []
        }

        var records: [ViewRecord] = []
        var order = 0
        var budget = Budget(deadline: deadline ?? .distantFuture)
        walk(rootView, depth: 0, order: &order, budget: &budget,
             bodyEvaluationPolicy: bodyEvaluationPolicy, into: &records)
        return records
    }

    // MARK: - Hosting controller detection

    private static func isHostingController(_ vc: UIViewController) -> Bool {
        SwiftUIDetection.isHostingController(vc)
    }

    private static func rootView(of controller: UIViewController) -> Any? {
        // ── Public path ───────────────────────────────────────────────
        // Every SwiftUI hosting controller — including the private
        // navigation/tab subclasses — is a `UIHostingController`, whose
        // `rootView` is PUBLIC API. The protocol conformance type-erases the
        // generic `Content` so we can read it from a plain `UIViewController`.
        // Works on every iOS version (documented property, not a layout
        // assumption).
        if let hosting = controller as? SwiftUIHostingRootProviding {
            return hosting.up_publicRootView
        }

        // ── Fallback: a stored SwiftUI View exposed via Mirror on an exotic
        //    host (Swift metadata reflection — no ObjC, no private selectors).
        //    Prefer a child named `rootView`. ───────────────────────────────
        var namedRootView: Any?
        var firstAnyView: Any?

        var mirror: Mirror? = Mirror(reflecting: controller)
        while let m = mirror {
            for child in m.children {
                guard child.value is any View else { continue }
                if child.label == "rootView" {
                    if namedRootView == nil { namedRootView = child.value }
                } else if firstAnyView == nil {
                    firstAnyView = child.value
                }
            }
            mirror = m.superclassMirror
        }
        return namedRootView ?? firstAnyView
    }

    // MARK: - Walk

    private struct Budget {
        var nodes = 0
        let maxNodes = 6_000
        // Depth is measured in MIRROR hops, not visible view nesting — every
        // modifier costs ~2-3 hops (ModifiedContent + storage), so a screen
        // wrapped in a handful of navigationDestination/section modifiers
        // easily exceeds 50 hops before its first button. Cost is bounded by
        // maxNodes; depth is only a recursion guard.
        let maxDepth = 160
        // Wall-clock cap. `.distantFuture` by default → node/depth-bounded only
        // (today's behavior); the scan path passes a real per-host deadline.
        let deadline: Date
        var exhausted: Bool { nodes >= maxNodes || Date() > deadline }
    }

    private static func isBridgingJunk(_ typeName: String) -> Bool {
        return typeName.contains("Representable") || typeName.contains("Coordinator")
            || typeName.contains("PlatformView") || typeName.contains("CollectionView")
            || typeName.contains("TableView") || typeName.contains("Graph")
            || typeName.contains("Bridge") || typeName.contains("Responder")
            // Accessibility attachments and resolved style storage are
            // attribute payloads, never content — and there are ~100 of them
            // on a styled screen (measured: they alone exhausted the budget).
            || typeName.contains("Accessibility") || typeName.contains("TextFieldStyle")
    }

    private static let opaqueLeafTypes: Set<String> = [
        "Image", "Color", "Font", "Path",
        "LinearGradient", "RadialGradient", "AngularGradient", "EllipticalGradient",
        "Rectangle", "RoundedRectangle", "UnevenRoundedRectangle",
        "Circle", "Capsule", "Ellipse", "ContainerRelativeShape",
        "Spacer", "Divider", "EdgeInsets", "EnvironmentValues", "PropertyList"
    ]

    private static func walk(
        _ value: Any,
        depth: Int,
        order: inout Int,
        budget: inout Budget,
        bodyEvaluationPolicy: BodyEvaluationPolicy,
        into records: inout [ViewRecord]
    ) {
        if budget.exhausted || depth > budget.maxDepth { return }
        budget.nodes += 1
        order += 1

        let typeName = stripGenericName(String(describing: type(of: value)))

        // Opaque leaves: paint/shape/symbol values whose internals can never
        // contain user views. Pruning them keeps the node budget for actual
        // content (a single gradient or SF Symbol otherwise costs dozens to
        // hundreds of Mirror nodes).
        if Self.opaqueLeafTypes.contains(typeName) { return }

        // ─── Recognise user-facing leaves ──────────────────────────────────
        if typeName == "Button" || typeName == "NavigationLink"
            || typeName == "Toggle" || typeName == "Menu" || typeName == "Link" {
            // The title MUST come from the control's `label` storage: a
            // NavigationLink's first string is otherwise its DESTINATION's
            // content, and a styled custom label sits behind several
            // ModifiedContent wrappers (hence the deep search). Fall back to
            // the whole value only when no label property exists.
            let labelSource = anyStoredChild(of: value, named: ["label", "_label"])
            if let title = findFirstString(under: labelSource ?? value, maxDepth: 24) {
                records.append(ViewRecord(title: title, viewType: typeName,
                                          depth: depth, order: order))
            }
            // Recurse ONLY into the label. A control's other stored children
            // are non-rendered payloads — a NavigationLink's `destination` is
            // an entire other screen. Walking those pollutes the inventory
            // with off-screen titles and burns the budget.
            if let labelSource {
                walk(labelSource, depth: depth + 1, order: &order,
                     budget: &budget, bodyEvaluationPolicy: bodyEvaluationPolicy,
                     into: &records)
                return
            }
        } else if typeName == "Text" {
            if let title = findFirstString(under: value, maxDepth: 8) {
                records.append(ViewRecord(title: title, viewType: "Text",
                                          depth: depth, order: order))
            }
            // A Text's internals (storage, fonts, modifiers) cannot contain
            // other views — recursing burns hundreds of budget nodes for
            // nothing.
            return
        } else if typeName.contains("UserpilotLabelInjector")
                    || typeName.contains("LabelCarrier") {
            if let label = findStoredString(in: value, named: "label") {
                records.append(ViewRecord(title: label, viewType: "UserpilotLabel",
                                          depth: depth, order: order))
            }
        }

        // Containers whose style/runtime internals can exhaust or pollute the
        // mirror walk. Their user-authored views live in label/content storage,
        // so walk only those payloads. This keeps GroupBox buttons visible to
        // the inventory instead of spending budget in GroupBoxStyle machinery.
        if typeName == "List" || typeName == "GroupBox" {
            if let label = anyStoredChild(of: value, named: ["label", "_label"]) {
                walk(label, depth: depth + 1, order: &order,
                     budget: &budget, bodyEvaluationPolicy: bodyEvaluationPolicy,
                     into: &records)
            }
            if let content = anyStoredChild(of: value, named: ["content", "_content"]) {
                walk(content, depth: depth + 1, order: &order,
                     budget: &budget, bodyEvaluationPolicy: bodyEvaluationPolicy,
                     into: &records)
            }
            return
        }

        // Backstop for other UIKit-bridging / runtime objects: they cannot
        // contain reflectable SwiftUI user views but can be enormous.
        if Self.isBridgingJunk(typeName) { return }

        // ─── Recurse ───────────────────────────────────────────────────────
        // Composite view (Body != Never): evaluate body and walk ONLY that.
        // Primitive view (Body == Never) or non-View value: Mirror into stored
        // children (where a Button's label/Text actually lives).
        if let body = Self.evaluatedBody(of: value, bodyEvaluationPolicy: bodyEvaluationPolicy) {
            walk(body, depth: depth + 1, order: &order, budget: &budget,
                 bodyEvaluationPolicy: bodyEvaluationPolicy, into: &records)
        } else {
            for child in Mirror(reflecting: value).children {
                // Presentation MODIFIERS (`navigationDestination`, sheets,
                // popovers) store fully-built view trees for screens that are
                // NOT on screen — never walk those. The check is restricted to
                // modifier types because NavigationStack's own internals store
                // the VISIBLE column under a `destination`-named child too.
                if child.label == "destination",
                   String(describing: type(of: value)).contains("Modifier") {
                    continue
                }
                walk(child.value, depth: depth + 1, order: &order,
                     budget: &budget, bodyEvaluationPolicy: bodyEvaluationPolicy,
                     into: &records)
                if budget.exhausted { return }
            }
        }
    }

    // MARK: - body evaluation (the load-bearing trick)

    /// Returns the result of `value.body` IF `value` is a composite SwiftUI
    /// `View` (i.e. `Body != Never`) whose body is SAFE to evaluate outside the
    /// graph. Returns nil for primitives, non-Views and environment-dependent
    /// views — callers then Mirror-recurse.
    private static func evaluatedBody(
        of value: Any,
        bodyEvaluationPolicy: BodyEvaluationPolicy
    ) -> Any? {
        guard let view = value as? any View else { return nil }
        guard !hasGraphDependentWrapper(view) else { return nil }
        guard shouldEvaluateWarningProneBody(view, bodyEvaluationPolicy: bodyEvaluationPolicy) else {
            return nil
        }
        return Self.bodyIfComposite(view)
    }

    /// Property-wrapper type names whose value is only valid inside SwiftUI's
    /// update graph. Evaluating a `body` that reads one outside the graph is a
    /// fatalError-level Swift trap that cannot be caught, so we refuse to
    /// evaluate the body of any view that stores one and degrade to Mirror.
    ///
    /// Seeded with `EnvironmentObject` only — the single wrapper proven to trap.
    /// `StateObject` / `State` are deliberately NOT denylisted: they default-
    /// initialize and extract titles fine. Add a wrapper here ONLY after
    /// validating its crash out-of-process (a denylisted wrapper silently loses
    /// that screen's titles, so the bar is "proven to trap", not "might").
    private static let graphDependentWrapperTypes: Set<String> = ["EnvironmentObject"]

    /// True when `view` stores any property wrapper from
    /// `graphDependentWrapperTypes` — i.e. evaluating its body is unsafe.
    private static func hasGraphDependentWrapper(_ view: Any) -> Bool {
        for child in Mirror(reflecting: view).children {
            let wrapper = stripGenericName(String(describing: type(of: child.value)))
            if graphDependentWrapperTypes.contains(wrapper) { return true }
        }
        return false
    }

    /// Wrappers that can log SwiftUI runtime warnings when read outside an
    /// installed view graph. These are not fatal-trap wrappers; the scan may
    /// still evaluate them when reflection is the only title source left.
    private static let warningProneWrapperTypes: Set<String> = [
        "State",
        "Binding",
        "StateObject",
        "ObservedObject",
        "Environment",
        "FocusState",
        "GestureState",
        "AppStorage",
        "SceneStorage"
    ]

    private static func shouldEvaluateWarningProneBody(
        _ view: Any,
        bodyEvaluationPolicy: BodyEvaluationPolicy
    ) -> Bool {
        switch bodyEvaluationPolicy {
        case .normal, .allowWarningProneAsLastResort:
            return true
        case .avoidWarningProneState:
            return !hasWarningProneWrapper(view)
        }
    }

    private static func hasWarningProneWrapper(_ view: Any) -> Bool {
        for child in Mirror(reflecting: view).children {
            let wrapper = stripGenericName(String(describing: type(of: child.value)))
            if warningProneWrapperTypes.contains(wrapper) { return true }
        }
        return false
    }

    /// Generic shim. Swift auto-opens the `any View` existential into `V`,
    /// giving access to the concrete `V.Body` associated type.
    private static func bodyIfComposite<V: View>(_ view: V) -> Any? {
        // Primitive views declare `typealias Body = Never`.
        if V.Body.self == Never.self { return nil }
        // Composite view — safe to evaluate.
        return view.body
    }

    // MARK: - String helpers

    private static func findFirstString(under value: Any, maxDepth: Int) -> String? {
        if maxDepth < 0 { return nil }

        // An Image's first stored string is its asset/symbol NAME
        // ("chevron.right") — never user-facing text. Skip the whole subtree
        // so an icon placed before a control's text can't hijack the title.
        if stripGenericName(String(describing: type(of: value))) == "Image" {
            return nil
        }

        if let s = value as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let attr = value as? NSAttributedString {
            let t = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let resolved = value as? LocalizedStringKey {
            // LocalizedStringKey hides its key in a stored `key` String.
            if let k = findStoredString(in: resolved, named: "key") { return k }
        }

        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            if let found = findFirstString(under: child.value, maxDepth: maxDepth - 1) {
                return found
            }
        }
        return nil
    }

    /// First stored child carrying any of `labels`, searched through the
    /// superclass-mirror chain.
    private static func anyStoredChild(of value: Any, named labels: [String]) -> Any? {
        var mirror: Mirror? = Mirror(reflecting: value)
        while let m = mirror {
            for child in m.children {
                if let label = child.label, labels.contains(label) { return child.value }
            }
            mirror = m.superclassMirror
        }
        return nil
    }

    private static func findStoredString(in value: Any, named property: String) -> String? {
        var mirror: Mirror? = Mirror(reflecting: value)
        while let m = mirror {
            for child in m.children where child.label == property {
                if let s = child.value as? String {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
                if let nested = findFirstString(under: child.value, maxDepth: 2) {
                    return nested
                }
            }
            mirror = m.superclassMirror
        }
        return nil
    }

    private static func stripGenericName(_ type: String) -> String {
        if let idx = type.firstIndex(of: "<") {
            return String(type[..<idx])
        }
        return type
    }
}
