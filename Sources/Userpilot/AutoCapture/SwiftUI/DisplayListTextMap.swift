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
//  Resilience: everything is structural Mirror reading with hard budgets. On an
//  OS where the internal layout shifted, extraction returns an empty map and
//  callers fall back — degrade, never crash.
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

        /// Returns true when the live layer geometry maps a window tap into this
        /// entry's owning hit frame.
        func containsWindowPoint(_ pointInWindow: CGPoint, in window: UIWindow) -> Bool {
            guard let layer, layer.superlayer != nil else { return false }
            let pointInLayer = layer.convert(pointInWindow, from: window.layer)
            let pointInContent = CGPoint(
                x: pointInLayer.x + textFrame.minX,
                y: pointInLayer.y + textFrame.minY
            )
            return hitFrame.contains(pointInContent)
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

    /// The text map for one hosting view. Empty when the display list can't be
    /// located or pairing fails — callers must treat that as "no information",
    /// not "no buttons".
    ///
    /// - Parameter deadline: optional wall-clock cap on the structural walk.
    ///   Defaults to `now + 50 ms` (today's per-host budget).
    static func textMap(for host: UIView,
                        deadline: Date? = nil,
                        maxVisited: Int = 1_500) -> [Entry] {
        guard let list = displayList(of: host) else { return [] }

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
        guard !items.isEmpty else { return [] }

        let layers = drawingLayers(under: host)
        return pair(items: items, with: layers)
    }

    // MARK: - Locate the live DisplayList

    /// Known stored-property path (current iOS):
    /// `_base.viewGraph.renderer.renderer.some.lastList`. Falls back to a
    /// budgeted BFS over the hosting view's stored properties so a renamed hop
    /// degrades gracefully instead of failing hard.
    private static func displayList(of host: UIView) -> Any? {
        if let base = storedChild(of: host, named: "_base"),
           let graph = storedChild(of: base, named: "viewGraph"),
           let renderer = storedChild(of: graph, named: "renderer"),
           let inner = storedChild(of: renderer, named: "renderer"),
           let list = storedChild(of: unwrapOptional(inner), named: "lastList"),
           String(describing: type(of: list)) == "DisplayList" {
            return list
        }

        var queue: [(Any, Int)] = [(host, 0)]
        var head = 0
        var visitedObjects = Set<ObjectIdentifier>()
        var visited = 0
        // Index cursor instead of `removeFirst()` (which is O(n) per dequeue →
        // O(n²) over the walk). FIFO order — and therefore BFS semantics — is
        // unchanged; we just advance `head` rather than shifting the array.
        while head < queue.count, visited < 8_000 {
            let (value, depth) = queue[head]
            head += 1
            visited += 1
            if depth > 8 { continue }
            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .class {
                let oid = ObjectIdentifier(value as AnyObject)
                if visitedObjects.contains(oid) { continue }
                visitedObjects.insert(oid)
            }
            for c in mirror.children {
                if c.label == "lastList",
                   String(describing: type(of: c.value)) == "DisplayList" {
                    return c.value
                }
                queue.append((c.value, depth + 1))
            }
        }
        return nil
    }

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
        let typeName = String(describing: type(of: value))
        if typeName == "DisplayList" {
            found(value)
            return
        }
        if shouldSkip(typeName) { return }
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
        if shouldSkip(String(describing: type(of: value))) { return nil }
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
            if layer.isHidden { return }
            if String(describing: type(of: layer)).contains("CGDrawingLayer") {
                result.append(layer)
            }
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
    private static func pair(items: [RawItem], with layers: [CALayer]) -> [Entry] {
        var entries: [Entry] = []
        let tolerance: CGFloat = 2.0
        var layerIndex = 0
        for item in items {
            var matched: CALayer?
            var probe = layerIndex
            while probe < layers.count {
                let bounds = layers[probe].bounds
                if abs(bounds.width - item.textFrame.width) <= tolerance,
                   abs(bounds.height - item.textFrame.height) <= tolerance {
                    matched = layers[probe]
                    layerIndex = probe + 1
                    break
                }
                probe += 1
            }
            guard let matched, item.title != nil else { continue }
            entries.append(Entry(
                title: item.title,
                textFrame: item.textFrame,
                hitFrame: item.hitFrame,
                layer: matched
            ))
        }
        return entries
    }
}
