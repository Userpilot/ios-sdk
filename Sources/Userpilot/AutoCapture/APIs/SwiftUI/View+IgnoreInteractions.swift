//
//  View+IgnoreInteractions.swift
//  Userpilot
//
//  Created by Userpilot on 15/03/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  View+IgnoreInteractions provides SwiftUI view modifiers for preventing interaction capture.
//  When applied, no interaction events will be captured for the view or its children.
//

import SwiftUI

// MARK: - Public API

/// Extension providing interaction ignoring functionality for SwiftUI views.
/// SwiftUI uses protocol extensions; API is `public` (not `open`—only classes support `open`).
public extension View {

    /// Prevents the Userpilot SDK from capturing any interaction events for this view and its children.
    ///
    /// Use this modifier to exclude certain views from analytics tracking.
    /// This is particularly useful for:
    ///
    /// - Test/debug UI elements that shouldn't be tracked
    /// - Demo content that's not part of the real user flow
    /// - Administrative controls
    /// - Views with sensitive interactions you don't want to track
    ///
    /// ## How it works
    ///
    /// This modifier applies the `userpilotIgnoreInteractions` property to the underlying UIKit view,
    /// which causes the Userpilot SDK to skip capturing any interaction events (taps, clicks, etc.)
    /// for this view and all its descendants.
    ///
    /// ## Usage Examples
    ///
    /// ```swift
    /// // Example 1: Ignore button interactions
    /// Button(action: { performDebugAction() }) {
    ///     Text("Debug Button")
    /// }
    /// .userpilotIgnoreInteractions(true)
    ///
    /// // Example 2: Ignore interactions in a list
    /// List(items, id: \.self) { item in
    ///     Text(item)
    ///         .userpilotIgnoreInteractions(true)
    /// }
    ///
    /// // Example 3: Ignore entire section
    /// Section {
    ///     Toggle("Debug Mode", isOn: $debugMode)
    ///     Button("Clear Cache") { clearCache() }
    ///     Button("Reset") { reset() }
    /// }
    /// .userpilotIgnoreInteractions(true)
    ///
    /// // Example 4: Ignore sensitive control panel
    /// VStack {
    ///     Text("Admin Panel")
    ///     Button("Delete All") { deleteAll() }
    ///     Button("Export Data") { exportData() }
    /// }
    /// .userpilotIgnoreInteractions(true)
    /// ```
    ///
    /// ## Important Notes
    ///
    /// - This modifier is recursive - if applied to a container view, all interactions in child views will be ignored
    /// - The views remain fully functional; only the analytics tracking is disabled
    /// - This does not affect manual tracking via `Userpilot.shared.track()`
    ///
    /// - Parameter ignore: Whether to ignore interactions (defaults to true)
    /// - Returns: A view with interaction tracking disabled
    @ViewBuilder
    func userpilotIgnoreInteractions(_ ignore: Bool = true) -> some View {
        self.modifier(UserpilotIgnoreInteractionsModifier(ignore: ignore))
    }
}

// MARK: - Private

/// Modifier that applies interaction ignoring to SwiftUI views via the underlying UIKit layer
private struct UserpilotIgnoreInteractionsModifier: ViewModifier {
    // MARK: - Properties

    /// Whether to ignore interactions
    let ignore: Bool

    // MARK: - ViewModifier Protocol

    /// Applies the ignore interactions modifier to the content
    /// - Parameter content: The content to modify
    /// - Returns: Modified view with interaction tracking disabled
    func body(content: Self.Content) -> some View {
        content
            .background(
                UserpilotIgnoreInteractionsRepresentable(ignore: ignore)
            )
    }
}

/// UIViewRepresentable that applies the userpilotIgnoreInteractions property to the UIKit view hierarchy
private struct UserpilotIgnoreInteractionsRepresentable: UIViewRepresentable {
    let ignore: Bool

    func makeUIView(context: Context) -> UserpilotIgnoreInteractionsView {
        return UserpilotIgnoreInteractionsView(ignore: ignore)
    }

    func updateUIView(_ uiView: UserpilotIgnoreInteractionsView, context: Context) {
        uiView.updateIgnoreInteractions(ignore)
    }
}

/// Internal UIView that applies the ignore interactions property to its parent view
private class UserpilotIgnoreInteractionsView: UIView {
    private var ignore: Bool
    private weak var appliedToView: UIView?

    init(ignore: Bool) {
        self.ignore = ignore
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateIgnoreInteractions(_ ignore: Bool) {
        self.ignore = ignore
        applyIgnoreInteractionsToParent()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyIgnoreInteractionsToParent()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyIgnoreInteractionsToParent()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyIgnoreInteractionsToParent()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        appliedToView?.userpilotIgnoreInteractions = false
        appliedToView = nil
    }

    private func applyIgnoreInteractionsToParent() {
        guard let parent = superview else {
            appliedToView?.userpilotIgnoreInteractions = false
            appliedToView = nil
            return
        }

        if appliedToView !== parent {
            appliedToView?.userpilotIgnoreInteractions = false
            appliedToView = parent
        }
        parent.userpilotIgnoreInteractions = ignore
    }
}
