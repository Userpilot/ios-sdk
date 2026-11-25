//
//  UIView+UserpilotTargetingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Regression cover for the SDK-generated `tab[N]` identity produced by the
//  UIKit traversal.
//
//  There was none before, which is exactly why `tab[N]` broke silently: UIKit
//  renamed the private tab-button class (`UITabBarButton` → `_UITabButton`),
//  moved it several levels below `UITabBar`, and started rendering *two*
//  complete sets of buttons at identical positions. Each of those alone turns
//  every tab selector into a miss or an `.ambiguous` failure, and nothing in the
//  suite noticed.
//
//  These tests therefore assert against a *real* `UITabBarController` in a real
//  laid-out `UIWindow`, never a hand-built stand-in: a fake hierarchy would have
//  kept passing through all three breakages.
//

import XCTest
@testable import Userpilot

final class UIViewUserpilotTargetingTests: XCTestCase {

    // MARK: Properties

    /// Retained for the whole test: the admitted host holds a weak window, so
    /// the test has to own the window it injects.
    private var window: UIWindow!

    private var tabBarController: UITabBarController!

    // MARK: Lifecycle

    override func setUp() {
        super.setUp()
        // An explicit iPhone-sized frame, because the traversal's visibility gate
        // is geometric: a zero-sized window would withhold every selector and the
        // tests would fail for the wrong reason.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        tabBarController = nil
        super.tearDown()
    }

    // MARK: Auto tags

    func testTabBar_tagsOneViewPerTab_orderedLeftToRight() throws {
        tabBarController = makeTabBarController(tabCount: 3)

        let tagged = try autoTaggedNodesSortedByX()

        XCTAssertEqual(tagged.count, 3, "expected exactly one tagged node per tab")
        guard tagged.count == 3 else { return }

        XCTAssertEqual(
            tagged.map { $0.selector?.toMap()["auto_tag"] },
            ["tab[0]", "tab[1]", "tab[2]"],
            "tab[N] is a left-to-right positional identity"
        )
        XCTAssertLessThan(tagged[0].bounds.midX, tagged[1].bounds.midX)
        XCTAssertLessThan(tagged[1].bounds.midX, tagged[2].bounds.midX)

        // The class-name predicate anchors both ends precisely so the bar's own
        // container views can never be mistaken for a tab.
        XCTAssertTrue(
            tagged.allSatisfy { $0.nativeType.hasSuffix("Button") },
            "a container was tagged as a tab: \(tagged.map { $0.nativeType })"
        )
    }

    /// Modern `UITabBar` renders two complete sets of tab buttons at identical
    /// frames (`SelectedContentView` and `ContentView`). Tagging both would make
    /// every tab selector resolve as `.ambiguous`, which is worse than the silent
    /// miss it replaced — so exactly one view may carry each index.
    func testTabBar_emitsEachTabIndexExactlyOnce() throws {
        tabBarController = makeTabBarController(tabCount: 3)

        let tagged = try autoTaggedNodesSortedByX()
        let middle = tagged.filter { $0.selector?.toMap()["auto_tag"] == "tab[1]" }

        XCTAssertEqual(middle.count, 1, "tab[1] must identify exactly one view")
    }

    func testHierarchyWithoutTabBar_producesNoAutoTags() throws {
        let root = UIViewController()
        root.view.backgroundColor = .white
        let plain = UIView(frame: CGRect(x: 10, y: 60, width: 120, height: 44))
        plain.accessibilityIdentifier = "plain-view"
        root.view.addSubview(plain)

        window.rootViewController = root
        layOutWindow()

        let node = try XCTUnwrap(window.userpilotElementNode())

        XCTAssertTrue(
            autoTaggedNodes(in: node).isEmpty,
            "only tab-bar buttons may receive a generated identity"
        )
    }

    // MARK: Resolution

    /// The end-to-end path a published tooltip actually takes: a decoded-shaped
    /// selector through `resolve(selector:)`, not a node dump.
    func testResolve_tabOneSelector_resolvesToTheMiddleTab() throws {
        tabBarController = makeTabBarController(tabCount: 3)

        let owner = MockUserpilot.make(config: Userpilot.Config(token: UUID().uuidString).defaultInstance(false))
        let registry = InstanceRegistry()
        registry.register(owner)
        window.attachUserpilotOwner(owner)
        let container = DIContainer()
        container.owner = owner
        container.register(Userpilot.Config.self, value: owner.config)
        container.register(InstanceRegistering.self, value: registry)
        container.register(InstanceResolving.self, value: InstanceResolver(registry: registry))
        container.register(UserpilotElementTargetingStrategy.self, value: NativeElementTargetingStrategy())
        let resolver = ElementResolver(container: container)
        let host = try XCTUnwrap(resolver.admitHost(in: window))

        let selector = ElementSelector(
            properties: SelectorProperties(autoTag: "tab[1]").toMap(),
            minimumScore: 5_000
        )

        let result = resolver.resolve(selector: selector, in: host)

        let tagged = try autoTaggedNodesSortedByX()
        XCTAssertEqual(tagged.count, 3)
        guard tagged.count == 3 else { return }

        switch result {
        case .success(let target):
            XCTAssertEqual(target.score, 5_000)
            XCTAssertEqual(target.rect, tagged[1].targetRect)
            XCTAssertGreaterThan(target.rect.midX, tagged[0].bounds.midX)
            XCTAssertLessThan(target.rect.midX, tagged[2].bounds.midX)
        case .failure(let error):
            XCTFail("expected tab[1] to resolve to the middle tab, got \(error)")
        }
    }

    // MARK: Walk

    func testElementNode_nodeIDsAreUniqueAcrossNestedLevels() throws {
        let root = UIViewController()
        for column in 0..<3 {
            let container = UIView(frame: CGRect(x: CGFloat(column) * 120, y: 80, width: 100, height: 300))
            for row in 0..<3 {
                container.addSubview(UIView(frame: CGRect(x: 0, y: CGFloat(row) * 60, width: 100, height: 40)))
            }
            root.view.addSubview(container)
        }
        window.rootViewController = root
        layOutWindow()

        let ids = nodeIDs(in: try XCTUnwrap(window.userpilotElementNode()))

        XCTAssertGreaterThan(ids.count, 12)
        XCTAssertEqual(Set(ids).count, ids.count, "WebView capture keys its replacements by node id")
    }

    func testElementNode_stopsDescendingOnceTheVisitCapIsSpent() throws {
        let root = UIViewController()
        for _ in 0..<(ElementTreeLimits.maxVisitedNodes + 100) {
            root.view.addSubview(UIView(frame: CGRect(x: 10, y: 80, width: 20, height: 20)))
        }
        let first = try XCTUnwrap(root.view.subviews.first)
        let last = try XCTUnwrap(root.view.subviews.last)
        window.rootViewController = root
        layOutWindow()

        let tree = try XCTUnwrap(window.userpilotElementNode())

        XCTAssertLessThanOrEqual(tree.nodeCount, ElementTreeLimits.maxVisitedNodes)
        XCTAssertTrue(contains(first, in: tree), "views walked before the cap stay in the tree")
        XCTAssertFalse(contains(last, in: tree), "views past the cap are not walked")
    }

    // MARK: Helpers

    private func nodeIDs(in node: ElementNode) -> [String] {
        node.children.reduce([node.nodeID]) { $0 + nodeIDs(in: $1) }
    }

    private func contains(_ view: UIView, in node: ElementNode) -> Bool {
        node.view === view || node.children.contains { contains(view, in: $0) }
    }

    /// Builds and lays out a real `UITabBarController` in the test window.
    private func makeTabBarController(tabCount: Int) -> UITabBarController {
        let controller = UITabBarController()
        controller.viewControllers = (0..<tabCount).map { index in
            let child = UIViewController()
            child.view.backgroundColor = .white
            child.tabBarItem = UITabBarItem(title: "Tab \(index)", image: nil, tag: index)
            return child
        }

        window.rootViewController = controller
        layOutWindow()
        controller.view.layoutIfNeeded()
        return controller
    }

    /// Makes the window visible and forces a synchronous layout pass.
    ///
    /// Both halves matter: the traversal prunes hidden subtrees, and it gates
    /// every selector on the view's centre point falling inside the safe area —
    /// an unlaid-out hierarchy has every frame at the origin and would be
    /// rejected before any identity is read.
    private func layOutWindow() {
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    /// Every node in the captured tree that carries a generated identity, in
    /// left-to-right screen order.
    private func autoTaggedNodesSortedByX() throws -> [ElementNode] {
        let root = try XCTUnwrap(window.userpilotElementNode())
        return autoTaggedNodes(in: root).sorted { $0.bounds.midX < $1.bounds.midX }
    }

    private func autoTaggedNodes(in node: ElementNode) -> [ElementNode] {
        var found: [ElementNode] = []
        if node.selector?.toMap()["auto_tag"] != nil {
            found.append(node)
        }
        for child in node.children {
            found.append(contentsOf: autoTaggedNodes(in: child))
        }
        return found
    }
}
