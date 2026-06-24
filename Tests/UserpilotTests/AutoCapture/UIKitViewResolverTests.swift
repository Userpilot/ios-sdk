//
//  UIKitViewResolverTests.swift
//  UserpilotTests
//
//  Verifies that `UIKitViewResolver.resolvePath(view:)` produces hierarchy
//  strings that are stable across navigation transitions and modal
//  presentations. The regression covered here is the `UITransitionView`
//  index flip that occurs after a `UINavigationController` push/pop, where
//  the live transition view's index inside `UIWindow.subviews` shifts from 0
//  to 1 once UIKit adds a snapshot/dimming sibling — which would otherwise
//  cause the same `UITextField` to produce two different hierarchy strings
//  on two visits.
//

import XCTest
@testable import Userpilot

final class UIKitViewResolverTests: XCTestCase {

    // MARK: - Stops at the owning view controller boundary

    func testHierarchy_stopsAtOwningViewControllerRootView() {
        let viewController = UIViewController()
        let scrollView = UIScrollView()
        let stack = UIStackView()
        let textField = UITextField()

        viewController.view.addSubview(scrollView)
        scrollView.addSubview(stack)
        stack.addArrangedSubview(textField)

        let path = UIKitViewResolver.resolvePath(view: textField)

        // The walk must stop at viewController.view (a plain `UIView`) and
        // never include classes above it.
        XCTAssertTrue(path.hasPrefix("UITextField:"), "Leaf must be the touched view")
        XCTAssertTrue(path.contains("UIScrollView"))
        XCTAssertTrue(path.contains("UIStackView"))
        XCTAssertTrue(
            path.hasSuffix("UIView:attr__index=\"0\""),
            "Path must terminate at the VC's root UIView, got \(path)"
        )
    }

    // MARK: - Skips UIKit private container chrome

    func testHierarchy_excludesUIWindow() {
        let window = UIWindow(frame: .zero)
        let viewController = UIViewController()
        let textField = UITextField()
        viewController.view.addSubview(textField)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let path = UIKitViewResolver.resolvePath(view: textField)

        XCTAssertFalse(
            path.contains("UIWindow"),
            "UIWindow ordering is unstable across multi-window apps (keyboard, overlays); excluded"
        )
        XCTAssertFalse(
            path.contains("UITransitionView"),
            "UITransitionView ordering is unstable across navigation; excluded"
        )
    }

    func testHierarchy_excludesAnyClassPrefixedWithUnderscore() {
        // Synthetic stand-in for `_UIScrollViewScrollIndicator`, `_UIDimmingView`, etc.
        let parent = UIView()
        let privateSibling = _PrivateLikeView()
        let stableSibling = UIView()
        parent.addSubview(privateSibling)
        parent.addSubview(stableSibling)

        // Wrap in a VC so the walk terminates cleanly.
        let viewController = UIViewController()
        viewController.view.addSubview(parent)

        let path = UIKitViewResolver.resolvePath(view: stableSibling)

        XCTAssertFalse(
            path.contains("_PrivateLikeView"),
            "Underscore-prefixed (private) classes must be skipped, got \(path)"
        )
    }

    // MARK: - Index stability

    func testHierarchy_indexIsStable_whenPrivateSiblingsAreAddedOrRemoved() {
        // Simulates the real bug: `UIWindow` subviews start with one ancestor;
        // after a navigation/modal cycle a transient sibling appears. The
        // stable sibling's index must not change.
        let viewController = UIViewController()
        let stable = UIView()
        viewController.view.addSubview(stable)

        let pathBefore = UIKitViewResolver.resolvePath(view: stable)

        // Insert a private-looking sibling before the stable one. The raw
        // `firstIndex(of:)` for `stable` would now be 1, but our walker must
        // still report 0 because the private sibling is filtered out.
        let transient = _PrivateLikeView()
        viewController.view.insertSubview(transient, at: 0)

        let pathAfter = UIKitViewResolver.resolvePath(view: stable)

        XCTAssertEqual(
            pathBefore, pathAfter,
            "Adding a transient private sibling must not shift the index of stable siblings"
        )
        XCTAssertTrue(
            pathBefore.contains("UIView:attr__index=\"0\""),
            "Stable view must remain at logical index 0, got \(pathBefore)"
        )
    }

    // MARK: - Leaf inclusion

    func testHierarchy_leafIsAlwaysIncluded_evenWhenItIsViewControllerRootView() {
        let viewController = UIViewController()
        // The "leaf" is the VC's own root view — touching the bare backdrop.
        let path = UIKitViewResolver.resolvePath(view: viewController.view)
        XCTAssertEqual(
            path, "UIView:attr__index=\"0\"",
            "The leaf must always be emitted, even when it is the VC's root view"
        )
    }

    func testHierarchy_isCompactWhenViewIsOrphan() {
        // No superview, no owning VC: the walk emits just the leaf and exits.
        let lonely = UITextField()
        XCTAssertEqual(
            UIKitViewResolver.resolvePath(view: lonely),
            "UITextField:attr__index=\"0\""
        )
    }
}

// MARK: - Test fixtures

/// Stand-in for a UIKit-private class. Class name starts with `_` so the
/// resolver's deny-list (`hasPrefix("_")`) treats it the same way it would
/// treat `_UIScrollViewScrollIndicator`, `_UIDimmingView`, etc.
private final class _PrivateLikeView: UIView {}
