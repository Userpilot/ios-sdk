//
//  DisplayListTextMap.swift
//  Userpilot
//
//  EXACT SwiftUI text geometry from the render tree — public API only.
//
//  SwiftUI paints a hosting view's content from a `DisplayList`: a tree of
//  items, each carrying a `frame` (relative to its parent item) and a content
//  payload. For text items the payload holds the RESOLVED string (localized,
//  interpolated). We read that structure with Swift `Mirror` (no ObjC, no
//  private selectors) and produce a "text map": every rendered text with
//    - its frame in display-list (content) space,
//    - a heuristic "hit frame" (the button background/container that visually
//      owns the text),
//    - the CALayer SwiftUI painted it into.
//
//  The layer is the coordinate bridge: each text/vector item is painted into
//  its own `SwiftUI.CGDrawingLayer`, in the same paint order as the display
//  list. Pairing items to layers by order + size lets the tap path convert a
//  window point into content space with the PUBLIC `CALayer.convert` — live, so
//
// swiftlint:disable file_length function_parameter_count identifier_name line_length type_body_length
// swiftlint:disable:previous blanket_disable_command
//  scrolling never stales the geometry.
//
//  Resilience: everything is structural Mirror reading with hard budgets. The
//  display list is located by a guided descent keyed on hop TYPES (the hops
//  differ between iOS 18 and 26), never by an open-ended search of SwiftUI's
//  internals. On an OS where the layout shifted, `scanHost` reports
//  `locatedDisplayList == false` (or unpaired text items), the scan cache's
//  circuit breaker turns capture off for the session — degrade, never crash.
//

import UIKit

internal enum DisplayListTextMap {

    struct Entry {
        /// Resolved visible text; nil for non-text vector drawings (kept only
        /// to preserve paint-order alignment while pairing layers).
        let title: String?
        /// Frame of the drawn text in display-list (content) space.
        let textFrame: CGRect
        /// The container that visually owns the text (button background, row,
        /// card) in display-list space — what a tap is tested against.
        let hitFrame: CGRect
        /// The layer this text was painted into; used at tap time to map window
        /// coordinates into content space.
        weak var layer: CALayer?
        /// The hosting view whose display list produced this entry; lets a
        /// single-host refresh replace only that host's entries.
        weak var host: UIView?

        /// Returns true when the live layer geometry maps a window tap into this
        /// entry's owning hit frame.
        func containsWindowPoint(_ pointInWindow: CGPoint, in window: UIWindow) -> Bool {
            guard let layer, layer.superlayer != nil, !Self.isHiddenOnScreen(layer) else { return false }
            let pointInLayer = layer.convert(pointInWindow, from: window.layer)
            let pointInContent = CGPoint(
                x: pointInLayer.x + textFrame.minX,
                y: pointInLayer.y + textFrame.minY
            )
            return hitFrame.contains(pointInContent)
        }

        /// A recycled lazy row keeps its drawing layer but hides it; its
        /// position then overlaps visible rows, so it must never be hit.
        private static func isHiddenOnScreen(_ layer: CALayer) -> Bool {
            var current: CALayer? = layer
            while let candidate = current {
                if candidate.isHidden || candidate.opacity <= 0 { return true }
                current = candidate.superlayer
            }
            return false
        }

        /// True when the text appears to sit inside a control/card background,
        /// rather than being a free-standing label or section header.
        var isStyledControlTitleCandidate: Bool {
            let extraHeight = hitFrame.height - textFrame.height
            let extraWidth = hitFrame.width - textFrame.width
            let hasBackground = extraHeight > 2 || extraWidth > 2
            return hasBackground && hitFrame.height <= 90
        }
    }

    // MARK: - Public entry points

    /// All hosting views in the window that own a SwiftUI render tree. Bounded
    /// by node/depth/deadline so the discovery walk on a deep hierarchy cannot
    /// itself become the source of main-thread jank.
    static func hostingViews(in window: UIWindow,
                             maxNodes: Int = SwiftUIScanBudget.hostingDiscoveryMaxNodes,
                             maxDepth: Int = SwiftUIScanBudget.hostingDiscoveryMaxDepth,
                             scanDeadline: Date = .distantFuture) -> [UIView] {
        hostingViews(under: window, maxNodes: maxNodes,
                     maxDepth: maxDepth, scanDeadline: scanDeadline)
    }

    /// Hosting views under an arbitrary root view. Used by one-shot scan APIs
    /// that intentionally scope work to one hosting controller's current view.
    static func hostingViews(under root: UIView,
                             maxNodes: Int = SwiftUIScanBudget.hostingDiscoveryMaxNodes,
                             maxDepth: Int = SwiftUIScanBudget.hostingDiscoveryMaxDepth,
                             scanDeadline: Date = .distantFuture) -> [UIView] {
        var result: [UIView] = []
        var visited = 0
        func walk(_ view: UIView, depth: Int) {
            guard visited < maxNodes, depth <= maxDepth, Date() <= scanDeadline else { return }
            visited += 1
            if SwiftUIDetection.isHostingView(view) {
                result.append(view)
            }
            for sub in view.subviews { walk(sub, depth: depth + 1) }
        }
        walk(root, depth: 0)
        return result
    }

    /// Result of scanning one hosting view.
    struct HostScan {
        let entries: [Entry]
        /// False when the host's display list could not be located — the render
        /// path moved (a new iOS release), as opposed to "no text on screen".
        let locatedDisplayList: Bool
        /// Text items found in the display list before layer pairing. Items
        /// with no paired entries mean the layer bridge moved.
        let textItemCount: Int
        /// The walk hit its node/time budget before finishing the list.
        let truncated: Bool

        static let notLocated = HostScan(entries: [], locatedDisplayList: false,
                                         textItemCount: 0, truncated: false)
    }

    /// Scans one hosting view. Empty entries mean "no information", not "no
    /// buttons"; `locatedDisplayList` / `textItemCount` tell the two apart.
    ///
    /// - Parameter deadline: optional wall-clock cap on the structural walk.
    ///   Defaults to `now + 50 ms`.
    static func scanHost(_ host: UIView,
                         deadline: Date? = nil,
                         maxVisited: Int = 1_500) -> HostScan {
        guard let list = displayList(of: host) else {
            #if DEBUG
            SwiftUIScanLog.log("DisplayListTextMap: no display list on \(type(of: host)) — render path moved?")
            #endif
            return .notLocated
        }

        var items: [RawItem] = []
        var budget = Budget(maxVisited: maxVisited,
                            deadline: deadline ?? Date().addingTimeInterval(0.050))
        walkList(list, origin: .zero, parentFrame: nil, inheritedPrevSibling: nil,
                 inheritedControlFrame: nil,
                 depth: 0, budget: &budget, into: &items)
        #if DEBUG
        if budget.isExhausted {
            SwiftUIScanLog.log("DisplayListTextMap truncated visited=\(budget.visited)/\(budget.maxVisited) rawItems=\(items.count)")
        }
        #endif
        let textItemCount = items.reduce(0) { $0 + ($1.title == nil ? 0 : 1) }
        guard !items.isEmpty else {
            return HostScan(entries: [], locatedDisplayList: true, textItemCount: 0,
                            truncated: budget.isExhausted)
        }

        let layers = drawingLayers(under: host)
        let entries = pair(items: items, with: layers, host: host)
        #if DEBUG
        if textItemCount > 0, entries.isEmpty {
            SwiftUIScanLog.log("DisplayListTextMap: \(textItemCount) text items but 0 paired "
                + "(drawing layers=\(layers.count)) on \(type(of: host)) — layer bridge moved?")
        }
        #endif
        return HostScan(entries: entries, locatedDisplayList: true, textItemCount: textItemCount,
                        truncated: budget.isExhausted)
    }

    // MARK: - Locate the live DisplayList

    /// Type-name fragments of the objects between a hosting view and its
    /// `lastList`. The hops differ per iOS release:
    ///   iOS 26: UIHostingViewBase → ViewGraphHost → ViewRenderer → ViewUpdater
    ///   iOS 18: UIHostingViewBase → ViewRenderer → ViewUpdater
    /// so instead of a fixed label path, the descent enters any child whose
    /// TYPE plays one of these roles. A hop being added, removed or renamed is
    /// tolerated, and nothing outside the render path is ever reflected.
    private static let renderPathTypeFragments = ["HostingViewBase", "ViewGraphHost", "Renderer", "Updater"]
    /// Back-references to the hosting view / controller and delegate hops.
    private static let renderPathExcludedTypeFragments = ["RendererHost", "Delegate"]
    private static let renderPathExcludedLabels: Set<String> = [
        "_rootView", "rootView", "host", "delegate", "viewController", "uiView"
    ]
    private static let renderPathMaxDepth = 6
    private static let renderPathMaxNodes = 48

    private static func displayList(of host: UIView) -> Any? {
        locateDisplayList(of: host).list
    }

    /// Guided depth-first descent from the hosting view to `lastList`. A
    /// matching child is entered immediately, so the search stops at the first
    /// working path and reads only the few fields before it at each hop —
    /// enumerating every field of a hosting view makes the runtime instantiate
    /// metadata for ~60 field types on first use (~100 ms measured). Bounded by
    /// depth and node count; class instances are visited once, so a
    /// back-reference to the hosting view ends that branch.
    private static func locateDisplayList(of host: UIView) -> (list: Any?, hops: [String]) {
        var visited = Set<ObjectIdentifier>()
        var nodes = 0
        var hops: [String] = []

        func descend(_ value: Any, depth: Int) -> Any? {
            guard depth <= renderPathMaxDepth, nodes < renderPathMaxNodes else { return nil }
            nodes += 1
            let value = unwrapOptional(value)
            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .class,
               !visited.insert(ObjectIdentifier(value as AnyObject)).inserted {
                return nil
            }

            var current: Mirror? = mirror
            while let m = current {
                for child in m.children {
                    let label = child.label ?? "_"
                    if renderPathExcludedLabels.contains(label) { continue }
                    switch renderHopKind(type(of: child.value)) {
                    case .displayList where label == "lastList":
                        hops.append("lastList")
                        return child.value
                    case .hop:
                        #if DEBUG
                        hops.append("\(label): \(type(of: child.value))")
                        #else
                        hops.append(label)
                        #endif
                        if let list = descend(child.value, depth: depth + 1) { return list }
                        hops.removeLast()
                    default:
                        break
                    }
                }
                current = m.superclassMirror
            }
            return nil
        }

        let list = descend(host, depth: 0)
        return (list, hops)
    }

    private enum RenderHopKind { case displayList, hop, other }

    private static let renderHopKind = TypeNameMemo { typeName -> RenderHopKind in
        if typeName == "DisplayList" { return .displayList }
        let isHop = renderPathTypeFragments.contains { typeName.contains($0) }
            && !renderPathExcludedTypeFragments.contains { typeName.contains($0) }
        return isHop ? .hop : .other
    }

    private static let isDisplayListType = TypeNameMemo { $0 == "DisplayList" }
    private static let isSkippedType = TypeNameMemo(.swift, shouldSkip)
    private static let isDrawingLayerType = TypeNameMemo(.runtimeClass) { $0.contains("CGDrawingLayer") }

    private static func unwrapOptional(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional, let first = mirror.children.first {
            return first.value
        }
        return value
    }

    private static func storedChild(of value: Any, named label: String) -> Any? {
        var mirror: Mirror? = Mirror(reflecting: value)
        while let m = mirror {
            for c in m.children where c.label == label { return c.value }
            mirror = m.superclassMirror
        }
        return nil
    }

    // MARK: - Structural walk

    private struct RawItem {
        let title: String?     // nil → vector drawing (spacer for pairing)
        let textFrame: CGRect  // absolute, display-list space
        let hitFrame: CGRect
    }

    private struct Budget {
        var visited = 0
        let maxVisited: Int
        // Injected by `textMap(for:deadline:)`; defaults to now + 50 ms there.
        let deadline: Date
        var isExhausted: Bool { visited >= maxVisited || Date() > deadline }
    }

    /// Iterates `list.items`. `parentFrame` is the absolute frame of the effect
    /// item that owns this list; `inheritedPrevSibling` is the absolute frame
    /// of the item that immediately preceded that effect item in ITS list (a
    /// button's background shape is usually exactly that sibling — e.g.
    /// `.borderedProminent`).
    private static func walkList(
        _ list: Any,
        origin: CGPoint,
        parentFrame: CGRect?,
        inheritedPrevSibling: CGRect?,
        inheritedControlFrame: CGRect?,
        depth: Int,
        budget: inout Budget,
        into items: inout [RawItem]
    ) {
        guard depth < 32, !budget.isExhausted else { return }
        guard let listItems = storedChild(of: list, named: "items") else { return }

        var prevSibling: CGRect? = inheritedPrevSibling
        for c in Mirror(reflecting: listItems).children {
            if budget.isExhausted { return }
            let absRect = walkItem(c.value, origin: origin, parentFrame: parentFrame,
                                   prevSibling: prevSibling,
                                   controlFrame: inheritedControlFrame,
                                   depth: depth,
                                   budget: &budget, into: &items)
            if let absRect { prevSibling = absRect }
        }
    }

    /// Processes one display-list item; returns its absolute frame.
    private static func walkItem(
        _ item: Any,
        origin: CGPoint,
        parentFrame: CGRect?,
        prevSibling: CGRect?,
        controlFrame: CGRect?,
        depth: Int,
        budget: inout Budget,
        into items: inout [RawItem]
    ) -> CGRect? {
        budget.visited += 1
        guard let frame = storedChild(of: item, named: "frame") as? CGRect else { return nil }
        let absRect = CGRect(x: origin.x + frame.origin.x, y: origin.y + frame.origin.y,
                             width: frame.width, height: frame.height)

        guard let value = storedChild(of: item, named: "value"),
              let valueCase = Mirror(reflecting: value).children.first else { return absRect }

        switch valueCase.label {
        case "content":
            guard let inner = storedChild(of: valueCase.value, named: "value"),
                  let contentCase = Mirror(reflecting: inner).children.first else { break }
            if contentCase.label == "text" {
                let title = firstString(under: contentCase.value, depth: 0, maxDepth: 8)
                items.append(RawItem(
                    title: title,
                    textFrame: absRect,
                    hitFrame: hitFrame(forText: absRect, parentFrame: parentFrame,
                                       prevSibling: prevSibling,
                                       controlFrame: controlFrame)
                ))
            } else if contentCase.label == "drawing" {
                // Vector drawing — also painted into a CGDrawingLayer; recorded
                // only to keep the pairing sequence aligned.
                items.append(RawItem(title: nil, textFrame: absRect, hitFrame: absRect))
            }

        case "effect":
            // .effect(Effect, DisplayList) — recurse into nested lists.
            let nextControlFrame = controlFrame ?? controlFrameCandidate(
                forContainer: absRect,
                parentFrame: parentFrame,
                prevSibling: prevSibling
            )
            findNestedLists(in: valueCase.value, depth: 0) { nested in
                walkList(nested, origin: absRect.origin, parentFrame: absRect,
                         inheritedPrevSibling: prevSibling,
                         inheritedControlFrame: nextControlFrame,
                         depth: depth + 1,
                         budget: &budget, into: &items)
            }

        default:
            break
        }
        return absRect
    }

    /// The rect a tap should be tested against for a given text:
    /// 1. the sibling drawn just before it when it encloses the text (button
    ///    background shapes — bordered styles, custom tiles);
    /// 2. else the owning effect item when it is plausibly a control (encloses
    ///    the text but isn't a whole-screen container);
    /// 3. else the text frame padded to a minimum touch target.
    private static func hitFrame(forText text: CGRect, parentFrame: CGRect?,
                                 prevSibling: CGRect?,
                                 controlFrame: CGRect?) -> CGRect {
        let maxControlHeight: CGFloat = 160
        if let controlFrame, controlFrame.contains(text),
           controlFrame.height <= maxControlHeight {
            return controlFrame
        }
        if let prev = prevSibling, prev.contains(text),
           prev.height <= maxControlHeight {
            return prev
        }
        if let parent = parentFrame, parent.contains(text),
           parent.height <= maxControlHeight {
            return parent
        }
        let minHeight: CGFloat = 44
        let dy = max(0, (minHeight - text.height) / 2)
        return text.insetBy(dx: -12, dy: -dy)
    }

    private static func controlFrameCandidate(forContainer container: CGRect,
                                              parentFrame: CGRect?,
                                              prevSibling: CGRect?) -> CGRect? {
        let maxControlHeight: CGFloat = 160
        if let prevSibling,
           prevSibling.contains(container),
           prevSibling.height <= maxControlHeight {
            return prevSibling
        }
        if let parentFrame,
           parentFrame.contains(container),
           parentFrame.height <= maxControlHeight {
            return parentFrame
        }
        if container.height <= maxControlHeight {
            return container
        }
        return nil
    }

    #if DEBUG
    /// Describes the render path of `host`: the hops the guided descent took to
    /// `lastList` (or the children of `_base` when it failed), the first
    /// display-list items' case labels, and a histogram of layer classes. This
    /// is the tool for a new iOS release: it shows which hop or layer type moved.
    /// Enable in a DEBUG build with the `UP_SUI_STRUCTURE=1` environment variable.
    internal static func debugDescribeRenderPath(of host: UIView) -> String {
        var lines: [String] = ["render path for \(type(of: host)):"]

        func childSummary(_ value: Any) -> String {
            var parts: [String] = []
            var mirror: Mirror? = Mirror(reflecting: value)
            while let m = mirror, parts.count < 40 {
                for c in m.children.prefix(40) {
                    parts.append("\(c.label ?? "_"): \(String(describing: type(of: c.value)).prefix(80))")
                }
                mirror = m.superclassMirror
            }
            return parts.joined(separator: " | ")
        }

        let located = locateDisplayList(of: host)
        if located.list != nil {
            lines.append("  ✓ " + located.hops.joined(separator: " → "))
        } else {
            lines.append("  ✗ lastList not found. host children: \(childSummary(host))")
            if let base = storedChild(of: host, named: "_base") {
                lines.append("  _base children: \(childSummary(unwrapOptional(base)))")
            }
        }

        if let list = located.list,
           let items = storedChild(of: list, named: "items") {
            for (index, item) in Mirror(reflecting: items).children.prefix(4).enumerated() {
                let value = storedChild(of: item.value, named: "value")
                let valueCase = value.flatMap { Mirror(reflecting: $0).children.first }
                var line = "  item[\(index)] fields: \(childSummary(item.value)) case=\(valueCase?.label ?? "nil")"
                if valueCase?.label == "content",
                   let inner = storedChild(of: valueCase!.value, named: "value"),
                   let contentCase = Mirror(reflecting: inner).children.first {
                    line += " content=\(contentCase.label ?? "nil")"
                }
                lines.append(line)
            }
        }

        var histogram: [String: Int] = [:]
        func walk(_ layer: CALayer, depth: Int) {
            guard depth < 40 else { return }
            histogram[String(describing: type(of: layer)), default: 0] += 1
            layer.sublayers?.forEach { walk($0, depth: depth + 1) }
        }
        walk(host.layer, depth: 0)
        let layerSummary = histogram.sorted { $0.value > $1.value }.map { "\($0.key)×\($0.value)" }
        lines.append("  layers: \(layerSummary.joined(separator: ", "))")
        return lines.joined(separator: "\n")
    }

    internal static func _testHitFrame(forText text: CGRect,
                                       parentFrame: CGRect?,
                                       prevSibling: CGRect?,
                                       controlFrame: CGRect?) -> CGRect {
        hitFrame(forText: text, parentFrame: parentFrame,
                 prevSibling: prevSibling, controlFrame: controlFrame)
    }
    #endif

    /// Finds DisplayList values shallowly inside an effect payload without
    /// crossing into graph/runtime objects.
    private static func findNestedLists(in value: Any, depth: Int, _ found: (Any) -> Void) {
        guard depth <= 3 else { return }
        let valueType = type(of: value)
        if isDisplayListType(valueType) {
            found(value)
            return
        }
        if isSkippedType(valueType) { return }
        for c in Mirror(reflecting: value).children {
            findNestedLists(in: c.value, depth: depth + 1, found)
        }
    }

    private static func shouldSkip(_ typeName: String) -> Bool {
        return typeName.contains("EnvironmentValues") || typeName.contains("PropertyList")
            || typeName.contains("UIKitPlatformViewHost") || typeName.contains("Graph")
            || typeName.contains("Coordinator") || typeName.contains("Context")
            || typeName.contains("Authority") || typeName.contains("Bridge")
            || typeName.contains("Responder") || typeName.contains("->")
            || typeName.contains("NavigationStack") || typeName.contains("AnyView")
    }

    private static func firstString(under value: Any, depth: Int, maxDepth: Int) -> String? {
        guard depth <= maxDepth else { return nil }
        if let s = value as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let attr = value as? NSAttributedString {
            let t = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if isSkippedType(type(of: value)) { return nil }
        for c in Mirror(reflecting: value).children {
            if let found = firstString(under: c.value, depth: depth + 1, maxDepth: maxDepth) {
                return found
            }
        }
        return nil
    }

    // MARK: - Layer pairing

    /// All SwiftUI drawing layers under the host's layer subtree, in paint
    /// order, stopping at nested hosting views (they own their own display
    /// lists and text maps).
    private static func drawingLayers(under host: UIView) -> [CALayer] {
        var result: [CALayer] = []
        func walk(_ layer: CALayer, depth: Int) {
            guard depth < 60, result.count < 800 else { return }
            if let delegateView = layer.delegate as? UIView,
               delegateView !== host,
               SwiftUIDetection.isHostingView(delegateView) {
                return
            }
            // Recycled lazy rows HIDE their drawing layer while the display
            // list still holds the row's items (measured iOS 26: 26 items,
            // 26 drawing layers, 5 hidden). Keeping hidden drawing layers in
            // the sequence keeps pairing aligned; tap-time hit tests skip them.
            if isDrawingLayerType(type(of: layer)) {
                result.append(layer)
            }
            if layer.isHidden { return }
            for sub in layer.sublayers ?? [] {
                walk(sub, depth: depth + 1)
            }
        }
        walk(host.layer, depth: 0)
        return result
    }

    /// Items and drawing layers are both in paint order with matching sizes;
    /// pair them with a forgiving two-pointer pass. Items that find no layer are
    /// dropped (no coordinate bridge → unusable).
    private static func pair(items: [RawItem], with layers: [CALayer], host: UIView) -> [Entry] {
        var matches: [CALayer?] = Array(repeating: nil, count: items.count)
        var layerIndex = 0
        for (index, item) in items.enumerated() {
            var probe = layerIndex
            while probe < layers.count {
                if sameSize(item.textFrame.size, layers[probe].bounds.size) {
                    matches[index] = layers[probe]
                    layerIndex = probe + 1
                    break
                }
                probe += 1
            }
        }

        var entries: [Entry] = []
        for (index, item) in items.enumerated() {
            guard let title = item.title, let matched = matches[index],
                  isPairingUnambiguous(index, items: items, matches: matches, layers: layers) else { continue }
            entries.append(Entry(
                title: title,
                textFrame: item.textFrame,
                hitFrame: item.hitFrame,
                layer: matched,
                host: host
            ))
        }
        return entries
    }

    private static func sameSize(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        let tolerance: CGFloat = 2.0
        return abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    /// Same-size texts are told apart only by paint order. When an item's size
    /// group holds DIFFERENT titles and its items and layers don't line up one
    /// to one, the greedy pass may have handed this text another text's layer —
    /// a wrong title on tap. Such entries are dropped: no title beats a wrong one.
    private static func isPairingUnambiguous(_ index: Int,
                                             items: [RawItem],
                                             matches: [CALayer?],
                                             layers: [CALayer]) -> Bool {
        let size = items[index].textFrame.size
        let peers = items.indices.filter { sameSize(items[$0].textFrame.size, size) }
        let distinctTitles = Set(peers.map { items[$0].title ?? "" })
        guard distinctTitles.count > 1 else { return true }
        let peerLayers = layers.reduce(0) { $0 + (sameSize($1.bounds.size, size) ? 1 : 0) }
        return peers.count == peerLayers && peers.allSatisfy { matches[$0] != nil }
    }
}
