//
//  View+RedactText.swift
//  Userpilot
//
//  Created by Userpilot on 15/03/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  View+RedactText provides SwiftUI view modifiers for marking text content as sensitive.
//  When applied, text will be replaced with "****" in captured events.
//

import SwiftUI

// MARK: - Public API

/// Extension providing text redaction functionality for SwiftUI views.
/// SwiftUI uses protocol extensions; API is `public` (not `open`—only classes support `open`).
public extension View {

    /// Marks text content in this view as sensitive and replaces it with "****" in captured events.
    ///
    /// Use this modifier to protect sensitive information from being captured in analytics events.
    /// This is particularly useful for:
    ///
    /// - Password fields
    /// - Credit card numbers
    /// - Personal information (SSN, ID numbers)
    /// - Financial data
    /// - Any other sensitive text content
    ///
    /// ## How it works
    ///
    /// This modifier applies the `userpilotRedactText` property to the underlying UIKit view,
    /// which causes the Userpilot SDK to replace any captured text with "****" instead of
    /// the actual content.
    ///
    /// ## Usage Examples
    ///
    /// ```swift
    /// // Example 1: Redact sensitive transaction value
    /// Text(transaction.value)
    ///     .foregroundStyle(.red)
    ///     .userpilotRedactText(true)
    ///
    /// // Example 2: Redact items in a list
    /// List(items, id: \.self) { item in
    ///     Text(item)
    ///         .userpilotRedactText(true)
    /// }
    ///
    ///
    /// // Example 4: Redact entire view containing multiple text elements
    /// VStack {
    ///     Text("Balance: $\(balance)")
    ///     Text("Account: \(accountNumber)")
    /// }
    /// .userpilotRedactText(true)
    /// ```
    ///
    /// ## Important Notes
    ///
    /// - This modifier is recursive - if applied to a container view, all text in child views will be redacted
    /// - The actual displayed text remains unchanged; only the captured analytics data is affected
    /// - You can also use the global config option `enableInteractionTextCapture(false)` to redact all text
    ///
    /// - Parameter redact: Whether to redact text content (defaults to true)
    /// - Returns: A view with text redaction applied
    @ViewBuilder
    func userpilotRedactText(_ redact: Bool = true) -> some View {
        self.modifier(UserpilotRedactTextModifier(redact: redact))
    }
}

// MARK: - Private

/// Modifier that applies text redaction to SwiftUI views via the underlying UIKit layer
private struct UserpilotRedactTextModifier: ViewModifier {
    // MARK: - Properties

    /// Whether to redact text content
    let redact: Bool

    // MARK: - ViewModifier Protocol

    /// Applies the redaction modifier to the content
    /// - Parameter content: The content to modify
    /// - Returns: Modified view with text redaction
    func body(content: Self.Content) -> some View {
        content
            .background(
                UserpilotRedactTextRepresentable(redact: redact)
            )
    }
}

/// UIViewRepresentable that applies the userpilotRedactText property to the UIKit view hierarchy
private struct UserpilotRedactTextRepresentable: UIViewRepresentable {
    let redact: Bool

    func makeUIView(context: Context) -> UserpilotRedactTextView {
        return UserpilotRedactTextView(redact: redact)
    }

    func updateUIView(_ uiView: UserpilotRedactTextView, context: Context) {
        uiView.updateRedactText(redact)
    }
}

/// Internal UIView that applies the redaction property to its parent view
private class UserpilotRedactTextView: UIView {
    private var redact: Bool
    private weak var appliedToView: UIView?

    init(redact: Bool) {
        self.redact = redact
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRedactText(_ redact: Bool) {
        self.redact = redact
        applyRedactTextToParent()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyRedactTextToParent()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyRedactTextToParent()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyRedactTextToParent()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        appliedToView?.userpilotRedactText = false
        appliedToView = nil
    }

    private func applyRedactTextToParent() {
        guard let parent = superview else {
            appliedToView?.userpilotRedactText = false
            appliedToView = nil
            return
        }

        if appliedToView !== parent {
            appliedToView?.userpilotRedactText = false
            appliedToView = parent
        }
        parent.userpilotRedactText = redact
    }
}
